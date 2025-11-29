import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:google_fonts/google_fonts.dart';
import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:image_picker/image_picker.dart';

class MapScreen extends StatefulWidget {
  const MapScreen({Key? key}) : super(key: key);

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  final MapController _mapController = MapController();
  final LatLng _initialCenter = LatLng(33.6844, 73.0479); // Islamabad
  LatLng? _tappedLocation;
  Map<String, dynamic>? _locationInfo;
  bool _isLoading = false;
  bool _isSaving = false;

  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _startDateController = TextEditingController();
  final TextEditingController _endDateController = TextEditingController();
  final TextEditingController _descController = TextEditingController();

  final supabase = Supabase.instance.client;
  final ImagePicker _imagePicker = ImagePicker();

  File? _selectedImage;
  String? _uploadedImageUrl;

  @override
  void dispose() {
    _titleController.dispose();
    _startDateController.dispose();
    _endDateController.dispose();
    _descController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    try {
      final XFile? image = await _imagePicker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1920,
        maxHeight: 1080,
        imageQuality: 85,
      );

      if (image != null) {
        setState(() {
          _selectedImage = File(image.path);
        });
      }
    } catch (e) {
      _showErrorSnackBar('Failed to pick image: $e');
    }
  }

  Future<String?> _uploadImage() async {
    if (_selectedImage == null) return null;

    try {
      final user = supabase.auth.currentUser;
      if (user == null) return null;

      final fileName = '${user.id}/${DateTime.now().millisecondsSinceEpoch}.jpg';

      await supabase.storage.from('Memories').upload(
        fileName,
        _selectedImage!,
        fileOptions: const FileOptions(cacheControl: '3600', upsert: false),
      );

      final imageUrl = supabase.storage.from('Memories').getPublicUrl(fileName);

      return imageUrl;
    } catch (e) {
      _showErrorSnackBar('Failed to upload image: $e');
      return null;
    }
  }

  Future<void> _fetchLocationInfo(LatLng point) async {
    setState(() {
      _isLoading = true;
      _tappedLocation = point;
    });

    try {
      final url = Uri.parse(
          'https://api.bigdatacloud.net/data/reverse-geocode-client?latitude=${point.latitude}&longitude=${point.longitude}&localityLanguage=en');

      final response = await http.get(url);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        setState(() {
          _locationInfo = data;
          _isLoading = false;
        });

        String locationName = '';
        if (data['city'] != null && data['city'].toString().isNotEmpty) {
          locationName = '${data['city']}, ${data['countryName'] ?? ''}';
        } else if (data['locality'] != null &&
            data['locality'].toString().isNotEmpty) {
          locationName = '${data['locality']}, ${data['countryName'] ?? ''}';
        } else {
          locationName = data['countryName'] ?? 'Unknown Location';
        }

        _titleController.text = locationName;

        _showAddMemoryForm();
      } else {
        setState(() => _isLoading = false);
        _showErrorSnackBar('Failed to fetch location info');
      }
    } catch (e) {
      setState(() => _isLoading = false);
      _showErrorSnackBar('Error: $e');
    }
  }

  Future<void> _saveToSupabase() async {
    if (_titleController.text.isEmpty ||
        _startDateController.text.isEmpty ||
        _endDateController.text.isEmpty ||
        _descController.text.isEmpty) {
      _showErrorSnackBar('Please fill in all fields');
      return;
    }

    setState(() => _isSaving = true);

    try {
      final user = supabase.auth.currentUser;
      if (user == null) {
        _showErrorSnackBar('You must be logged in');
        setState(() => _isSaving = false);
        return;
      }

      String? imageUrl;
      if (_selectedImage != null) imageUrl = await _uploadImage();

      final entryData = {
        'user_id': user.id,
        'latitude': _tappedLocation!.latitude,
        'longitude': _tappedLocation!.longitude,
        'city_name': _locationInfo?['city'],
        'country_name': _locationInfo?['countryName'],
        'locality': _locationInfo?['locality'],
        'title': _titleController.text.trim(),
        'description': _descController.text.trim(),
        'visit_start_date': _startDateController.text.trim(),
        'visit_end_date': _endDateController.text.trim(),
        'image_url': imageUrl ?? 'assets/images/default.jpg',
      };

      await supabase.from('travel_entries').insert(entryData);

      _titleController.clear();
      _startDateController.clear();
      _endDateController.clear();
      _descController.clear();
      _selectedImage = null;

      setState(() => _isSaving = false);
      if (mounted) Navigator.pop(context);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('✅ Memory saved!', style: GoogleFonts.poppins()),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      setState(() => _isSaving = false);
      _showErrorSnackBar('Failed to save: $e');
    }
  }

  void _showAddMemoryForm() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return StatefulBuilder(builder: (context, setModalState) {
          return Padding(
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(context).viewInsets.bottom,
            ),
            child: DraggableScrollableSheet(
              initialChildSize: 0.75,
              maxChildSize: 0.95,
              expand: false,
              builder: (context, scrollController) {
                return Container(
                  padding: const EdgeInsets.all(20),
                  child: ListView(
                    controller: scrollController,
                    children: [
                      Center(
                        child: Container(
                          width: 40,
                          height: 4,
                          decoration: BoxDecoration(
                            color: Colors.grey[300],
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),

                      Text('Add Memory',
                          style: GoogleFonts.poppins(
                              fontSize: 24, fontWeight: FontWeight.w600)),

                      const SizedBox(height: 24),

                      GestureDetector(
                        onTap: () async {
                          await _pickImage();
                          setModalState(() {});
                        },
                        child: Container(
                          height: 200,
                          decoration: BoxDecoration(
                            color: Colors.grey[100],
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.grey[300]!),
                          ),
                          child: _selectedImage != null
                              ? ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: Image.file(
                              _selectedImage!,
                              width: double.infinity,
                              height: 200,
                              fit: BoxFit.cover,
                            ),
                          )
                              : Column(
                            mainAxisAlignment:
                            MainAxisAlignment.center,
                            children: [
                              Icon(
                                  Icons.add_photo_alternate_outlined,
                                  size: 60,
                                  color: Colors.grey[400]),
                              const SizedBox(height: 12),
                              Text('Tap to add photo',
                                  style: GoogleFonts.poppins(
                                      fontSize: 16,
                                      color: Colors.grey[600])),
                            ],
                          ),
                        ),
                      ),

                      const SizedBox(height: 24),

                      Text("Title",
                          style: GoogleFonts.poppins(
                              fontSize: 14, fontWeight: FontWeight.w600)),
                      const SizedBox(height: 8),
                      TextField(
                        controller: _titleController,
                        decoration: _inputDecoration("e.g., Tokyo, Japan"),
                        style: GoogleFonts.poppins(),
                      ),
                      const SizedBox(height: 16),

                      Text("Start Date",
                          style: GoogleFonts.poppins(
                              fontSize: 14, fontWeight: FontWeight.w600)),
                      const SizedBox(height: 8),
                      TextField(
                        controller: _startDateController,
                        readOnly: true,
                        decoration: _dateDecoration(),
                        onTap: () async {
                          final picked = await showDatePicker(
                            context: context,
                            initialDate: DateTime.now(),
                            firstDate: DateTime(2000),
                            lastDate: DateTime.now(),
                          );
                          if (picked != null) {
                            _startDateController.text =
                                _formatDate(picked);
                          }
                        },
                      ),
                      const SizedBox(height: 16),

                      Text("End Date",
                          style: GoogleFonts.poppins(
                              fontSize: 14, fontWeight: FontWeight.w600)),
                      const SizedBox(height: 8),
                      TextField(
                        controller: _endDateController,
                        readOnly: true,
                        decoration: _dateDecoration(),
                        onTap: () async {
                          final picked = await showDatePicker(
                            context: context,
                            initialDate: DateTime.now(),
                            firstDate: DateTime(2000),
                            lastDate: DateTime.now(),
                          );
                          if (picked != null) {
                            _endDateController.text =
                                _formatDate(picked);
                          }
                        },
                      ),
                      const SizedBox(height: 16),

                      Text("Description",
                          style: GoogleFonts.poppins(
                              fontSize: 14, fontWeight: FontWeight.w600)),
                      const SizedBox(height: 8),
                      TextField(
                        controller: _descController,
                        maxLines: 4,
                        decoration: _inputDecoration(
                            "Share your experience here..."),
                      ),

                      const SizedBox(height: 24),

                      ElevatedButton(
                        onPressed: _isSaving ? null : _saveToSupabase,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF3D8BFF),
                          padding:
                          const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12)),
                        ),
                        child: _isSaving
                            ? const CircularProgressIndicator(
                            color: Colors.white)
                            : Text("Add to Timeline",
                            style: GoogleFonts.poppins(
                                fontSize: 16,
                                fontWeight: FontWeight.w600)),
                      ),
                    ],
                  ),
                );
              },
            ),
          );
        });
      },
    );
  }

  InputDecoration _inputDecoration(String hint) {
    return InputDecoration(
      hintText: hint,
      hintStyle: GoogleFonts.poppins(color: Colors.grey[400]),
      filled: true,
      fillColor: Colors.grey[50],
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: Colors.grey[300]!),
      ),
    );
  }

  InputDecoration _dateDecoration() {
    return InputDecoration(
      hintText: "Select date",
      hintStyle: GoogleFonts.poppins(color: Colors.grey[400]),
      filled: true,
      fillColor: Colors.grey[50],
      suffixIcon:
      const Icon(Icons.calendar_today, color: Color(0xFF3D8BFF)),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: Colors.grey[300]!),
      ),
    );
  }

  String _formatDate(DateTime d) =>
      "${_getMonthName(d.month)} ${d.day}, ${d.year}";

  String _getMonthName(int month) {
    const months = [
      'Jan','Feb','Mar','Apr','May','Jun',
      'Jul','Aug','Sep','Oct','Nov','Dec'
    ];
    return months[month - 1];
  }

  void _showErrorSnackBar(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
          content:
          Text(msg, style: GoogleFonts.poppins()),
          backgroundColor: Colors.red),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F8FC),
      appBar: AppBar(
        title: Text("Map",
            style: GoogleFonts.poppins(
                color: Colors.black87,
                fontWeight: FontWeight.w600)),
        centerTitle: true,
        backgroundColor: Colors.white,
      ),
      body: Stack(
        children: [
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: _initialCenter,
              initialZoom: 13.0,
              onTap: (tapPos, point) => _fetchLocationInfo(point),
            ),
            children: [
              TileLayer(
                  urlTemplate:
                  'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                  userAgentPackageName: 'com.example.mad_project'),
              MarkerLayer(markers: [
                Marker(
                    point: _initialCenter,
                    child: const Icon(Icons.location_pin,
                        color: Colors.blue, size: 40)),
                if (_tappedLocation != null)
                  Marker(
                      point: _tappedLocation!,
                      child: const Icon(Icons.location_on,
                          color: Colors.red, size: 40)),
              ])
            ],
          ),
          if (_isLoading)
            Container(
              color: Colors.black.withOpacity(0.3),
              child: const Center(
                  child: CircularProgressIndicator(
                      color: Color(0xFF3D8BFF))),
            )
        ],
      ),
    );
  }
}
