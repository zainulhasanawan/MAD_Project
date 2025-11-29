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

  List<String> photoMemories = [];
  bool isLoadingPhotos = true;
  bool isUploading = false;

  @override
  void initState() {
    super.initState();
    _loadPhotoMemories();
  }

  // ------------------------------------------------
  // LOAD EXTRA PHOTOS FROM DB
  // ------------------------------------------------
  Future<void> _loadPhotoMemories() async {
    setState(() => isLoadingPhotos = true);

    try {
      final res = await supabase
          .from('memory_photos')
          .select('image_url')
          .eq('trip_id', widget.trip['id']);

      setState(() {
        photoMemories =
            res.map<String>((e) => e['image_url'] as String).toList();
        isLoadingPhotos = false;
      });
    } catch (e) {
      debugPrint("Photo load error: $e");
      setState(() => isLoadingPhotos = false);
    }
  }

  // ------------------------------------------------
  // DATE CALCULATION
  // ------------------------------------------------
  int? _calculateDuration() {
    final start = _parseDate(widget.trip['visit_start_date']);
    final end = _parseDate(widget.trip['visit_end_date']);

    if (start != null && end != null) {
      return end.difference(start).inDays + 1;
    }
    return null;
  }

  DateTime? _parseDate(String? textDate) {
    if (textDate == null || textDate.isEmpty) return null;

    try {
      final parts = textDate.split(' ');
      final months = {
        'Jan': 1, 'Feb': 2, 'Mar': 3, 'Apr': 4,
        'May': 5, 'Jun': 6, 'Jul': 7, 'Aug': 8,
        'Sep': 9, 'Oct': 10, 'Nov': 11, 'Dec': 12,
      };

      return DateTime(
        int.parse(parts[2].replaceAll(',', '')),
        months[parts[0]]!,
        int.parse(parts[1].replaceAll(',', '')),
      );
    } catch (_) {
      return null;
    }
  }

  // ------------------------------------------------
  // ADD PHOTO → STORAGE + DB ✅ FIXED
  // ------------------------------------------------
  Future<void> _addPhoto() async {
    final picked = await _picker.pickImage(source: ImageSource.gallery);
    if (picked == null) return;

    setState(() => isUploading = true);

    try {
      final user = supabase.auth.currentUser!;
      final file = File(picked.path);

      final fileName =
          'extra_${DateTime.now().millisecondsSinceEpoch}.jpg';
      final path = '${user.id}/$fileName';

      await supabase.storage
          .from('Memories')
          .upload(path, file, fileOptions: const FileOptions(upsert: true));

      final imageUrl =
      supabase.storage.from('Memories').getPublicUrl(path);

      await supabase.from('memory_photos').insert({
        'trip_id': widget.trip['id'],
        'image_url': imageUrl,
      });

      await _loadPhotoMemories();

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("✅ Photo added successfully")),
      );
    } catch (e) {
      debugPrint("Add photo error: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("❌ Failed to add photo")),
      );
    } finally {
      setState(() => isUploading = false);
    }
  }

  // ------------------------------------------------
  // UI
  // ------------------------------------------------
  @override
  Widget build(BuildContext context) {
    final duration = _calculateDuration();

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
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _mainImage(),
            const SizedBox(height: 16),
            _visitInfo(duration),
            const SizedBox(height: 16),
            _notes(),
            const SizedBox(height: 16),
            _photoSection(),
          ],
        ),
      ),
    );
  }

  // ------------------------------------------------
  // UI COMPONENTS
  // ------------------------------------------------
  Widget _mainImage() {
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: widget.trip['image_url'] != null
          ? Image.network(
        widget.trip['image_url'],
        height: 220,
        width: double.infinity,
        fit: BoxFit.cover,
      )
          : _placeholder(),
    );
  }

  Widget _visitInfo(int? duration) {
    return _card(
      "Visit Details",
      [
        _row(Icons.date_range, "From",
            widget.trip['visit_start_date'] ?? "N/A"),
        _row(Icons.date_range, "To",
            widget.trip['visit_end_date'] ?? "N/A"),
        if (duration != null)
          _row(Icons.timelapse, "Duration", "$duration days"),
        if (widget.trip['lat'] != null && widget.trip['lng'] != null)
          _row(Icons.location_on, "Coordinates",
              "${widget.trip['lat']}, ${widget.trip['lng']}"),
      ],
    );
  }

  Widget _notes() {
    return _card("My Notes", [
      Text(
        widget.trip['desc'] ?? "No description available",
        style: GoogleFonts.poppins(height: 1.5),
      ),
    ]);
  }

  Widget _photoSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text("Photo Memories",
            style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
        const SizedBox(height: 10),

        if (isLoadingPhotos)
          const Center(child: CircularProgressIndicator()),

        SizedBox(
          height: 110,
          child: ListView(
            scrollDirection: Axis.horizontal,
            children: [
              GestureDetector(
                onTap: isUploading ? null : _addPhoto,
                child: _addTile(),
              ),
              const SizedBox(width: 10),

              if (widget.trip['image_url'] != null &&
                  !photoMemories.contains(widget.trip['image_url']))
                _photoTile(widget.trip['image_url']),

              ...photoMemories.map(_photoTile),
            ],
          ),
        ),
      ],
    );
  }

  // ------------------------------------------------
  // SHARED WIDGETS
  // ------------------------------------------------
  Widget _card(String title, List<Widget> children) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(title,
            style:
            GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w600)),
        const SizedBox(height: 10),
        ...children,
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
          Text("$label: ",
              style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
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
        child:
        Image.network(url, width: 120, height: 100, fit: BoxFit.cover),
      ),
    );
  }

  Widget _addTile() {
    return Container(
      width: 120,
      height: 100,
      decoration: BoxDecoration(
          color: Colors.grey.shade200,
          borderRadius: BorderRadius.circular(10)),
      child: isUploading
          ? const Center(child: CircularProgressIndicator())
          : const Icon(Icons.add_a_photo_outlined,
          size: 36, color: Colors.grey),
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
