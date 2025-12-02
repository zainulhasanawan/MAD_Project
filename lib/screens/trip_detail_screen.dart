import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class TripDetailScreen extends StatefulWidget {
  final Map<String, dynamic> trip;

  const TripDetailScreen({Key? key, required this.trip}) : super(key: key);

  @override
  State<TripDetailScreen> createState() => _TripDetailScreenState();
}

class _TripDetailScreenState extends State<TripDetailScreen> {
  final supabase = Supabase.instance.client;
  final ImagePicker _picker = ImagePicker();

  List<String> imageList = [];
  bool isUploading = false;

  @override
  void initState() {
    super.initState();
    _loadImagesFromTrip();
  }

  // FETCH UPDATED TRIP FROM SUPABASE
  Future<void> fetchTrip() async {
    try {
      final updatedTrip = await supabase
          .from('travel_entries')
          .select()
          .eq('id', widget.trip['id'])
          .single();

      if (updatedTrip != null) {
        setState(() {
          widget.trip.addAll(updatedTrip);
          _loadImagesFromTrip();
        });
      }
    } catch (e) {
      debugPrint("Error fetching trip: $e");
    }
  }

  // LOAD IMAGES FROM TRIP
  void _loadImagesFromTrip() {
    final imgs = widget.trip['image_url'];
    setState(() {
      if (imgs is List) {
        imageList = imgs.map((e) => e.toString()).toList();
      } else {
        imageList = [];
      }
    });
  }

  // ADD MULTIPLE IMAGES — REMOVE ERROR IMG
  Future<void> _addPhotos() async {
    final pickedFiles = await _picker.pickMultiImage();
    if (pickedFiles.isEmpty) return;

    setState(() => isUploading = true);

    try {
      final user = supabase.auth.currentUser!;
      List<String> newUrls = [];

      final cleanedExisting = imageList
          .where((e) =>
      !e.contains("error") &&
          !e.contains("placeholder") &&
          !e.contains("default") &&
          e.trim().isNotEmpty)
          .toList();

      for (int i = 0; i < pickedFiles.length; i++) {
        final file = File(pickedFiles[i].path);
        final fileName =
            '${user.id}/${DateTime.now().millisecondsSinceEpoch}_${cleanedExisting.length + i}.jpg';

        await supabase.storage.from("Memories").upload(
          fileName,
          file,
          fileOptions: const FileOptions(cacheControl: '3600', upsert: false),
        );

        final imageUrl = supabase.storage.from("Memories").getPublicUrl(fileName);
        newUrls.add(imageUrl);
      }

      final updatedArray = [...cleanedExisting, ...newUrls];

      await supabase
          .from("travel_entries")
          .update({"image_url": updatedArray}).eq("id", widget.trip['id']);

      setState(() => imageList = updatedArray);

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Photos added successfully")),
      );

      await fetchTrip();
    } catch (e) {
      debugPrint("Upload error: $e");
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text("Failed: $e")));
    }

    setState(() => isUploading = false);
  }

  // DELETE IMAGE
  Future<void> _deleteImage(String url) async {
    final path = url.split("/Memories/").last;

    try {
      await supabase.storage.from("Memories").remove([path]);

      final updatedList = [...imageList]..remove(url);

      await supabase
          .from("travel_entries")
          .update({"image_url": updatedList}).eq("id", widget.trip['id']);

      setState(() => imageList = updatedList);
      await fetchTrip();
    } catch (e) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text("Delete failed: $e")));
    }
  }

  // EDIT TITLE + DESC
  Future<void> _editDetails() async {
    final titleController =
    TextEditingController(text: widget.trip['title'] ?? "");
    final descController =
    TextEditingController(text: widget.trip['desc'] ?? "");

    await showDialog(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text("Edit Memory"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
                controller: titleController,
                decoration: const InputDecoration(labelText: "Title")),
            TextField(
                controller: descController,
                decoration: const InputDecoration(labelText: "Description")),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c), child: const Text("Cancel")),
          ElevatedButton(
              onPressed: () async {
                await supabase.from("travel_entries").update({
                  "title": titleController.text,
                  "description": descController.text,
                }).eq("id", widget.trip['id']);

                widget.trip['title'] = titleController.text;
                widget.trip['desc'] = descController.text;
                setState(() {});

                await fetchTrip();
                Navigator.pop(c);
              },
              child: const Text("Save"))
        ],
      ),
    );
  }

  // UI
  @override
  Widget build(BuildContext context) {
    String? mainImg = imageList.isNotEmpty ? imageList.first : null;

    return Scaffold(
      backgroundColor: const Color(0xFFF8F8FC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        title: Text(
          widget.trip['title'] ?? 'Trip Details',
          style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Colors.black87),
          onPressed: () => Navigator.pop(context, true),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit, color: Colors.black87),
            onPressed: _editDetails,
          )
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: mainImg != null
                  ? Image.network(mainImg,
                  height: 220, width: double.infinity, fit: BoxFit.cover)
                  : _placeholder(),
            ),
            const SizedBox(height: 16),
            _infoCard(),
            const SizedBox(height: 16),
            _notesSection(),
            const SizedBox(height: 16),
            _photosSection(),
          ],
        ),
      ),
    );
  }

  // REUSABLE WIDGETS
  Widget _infoCard() {
    return _card(
      "Visit Details",
      [
        _row(Icons.date_range, "From", widget.trip['visit_start_date'] ?? "N/A"),
        _row(Icons.date_range, "To", widget.trip['visit_end_date'] ?? "N/A"),
        if (widget.trip['lat'] != null)
          _row(Icons.location_on, "Lat", widget.trip['lat'].toString()),
        if (widget.trip['lng'] != null)
          _row(Icons.location_on, "Lng", widget.trip['lng'].toString()),
      ],
    );
  }

  Widget _notesSection() {
    return _card(
      "My Notes",
      [
        Text(
          widget.trip['desc'] ?? "No description available",
          style: GoogleFonts.poppins(height: 1.5),
        )
      ],
    );
  }

  Widget _photosSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text("All Photos", style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
        const SizedBox(height: 10),
        SizedBox(
          height: 110,
          child: ListView(
            scrollDirection: Axis.horizontal,
            children: [
              GestureDetector(onTap: _addPhotos, child: _addTile()),
              const SizedBox(width: 10),
              ...imageList.map((url) => GestureDetector(
                onLongPress: () {
                  showDialog(
                    context: context,
                    builder: (c) => AlertDialog(
                      title: const Text("Delete Photo?"),
                      content: const Text("This cannot be undone."),
                      actions: [
                        TextButton(
                            onPressed: () => Navigator.pop(c),
                            child: const Text("Cancel")),
                        ElevatedButton(
                            onPressed: () async {
                              Navigator.pop(c);
                              await _deleteImage(url);
                            },
                            child: const Text("Delete"))
                      ],
                    ),
                  );
                },
                child: _photoTile(url),
              )),
            ],
          ),
        )
      ],
    );
  }

  Widget _card(String title, List<Widget> children) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
          color: Colors.white, borderRadius: BorderRadius.circular(12)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(title,
            style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w600)),
        const SizedBox(height: 10),
        ...children
      ]),
    );
  }

  Widget _row(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          Icon(icon, size: 18, color: const Color(0xFF3D8BFF)),
          const SizedBox(width: 8),
          Text("$label: ", style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
          Expanded(child: Text(value, style: GoogleFonts.poppins())),
        ],
      ),
    );
  }

  Widget _photoTile(String url) {
    return Padding(
      padding: const EdgeInsets.only(right: 10),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(10),
        child: Image.network(url, width: 120, height: 100, fit: BoxFit.cover),
      ),
    );
  }

  Widget _addTile() {
    return Container(
      width: 120,
      height: 100,
      decoration: BoxDecoration(
        color: Colors.grey.shade200,
        borderRadius: BorderRadius.circular(10),
      ),
      child: isUploading
          ? const Center(child: CircularProgressIndicator())
          : const Icon(Icons.add_a_photo_outlined, size: 36, color: Colors.grey),
    );
  }

  Widget _placeholder() {
    return Container(
      height: 220,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        gradient: LinearGradient(colors: [
          const Color(0xFF3D8BFF).withOpacity(0.7),
          const Color(0xFF3D8BFF).withOpacity(0.4),
        ]),
      ),
    );
  }
}