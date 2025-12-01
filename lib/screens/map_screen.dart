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
  final LatLng _initialCenter = LatLng(33.6844, 73.0479);
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

  // Store actual DateTime objects for validation
  DateTime? _startDate;
  DateTime? _endDate;

  // Support multiple images
  List<File> _selectedImages = [];

  @override
  void dispose() {
    _titleController.dispose();
    _startDateController.dispose();
    _endDateController.dispose();
    _descController.dispose();
    super.dispose();
  }

  /// Pick multiple images and append to _selectedImages
  Future<void> _pickImages() async {
    try {
      final List<XFile>? images = await _imagePicker.pickMultiImage(
        maxWidth: 1920,
        maxHeight: 1080,
        imageQuality: 85,
      );

      if (images != null && images.isNotEmpty) {
        setState(() {
          _selectedImages.addAll(images.map((x) => File(x.path)));
        });
      }
    } catch (e) {
      _showErrorSnackBar('Failed to pick images: $e');
    }
  }

  /// Upload multiple images to Supabase Storage and return list of public URLs
  Future<List<String>> _uploadImages() async {
    final List<String> uploadedUrls = [];

    if (_selectedImages.isEmpty) return uploadedUrls;

    try {
      final user = supabase.auth.currentUser;
      if (user == null) return uploadedUrls;

      final bucket = 'Memories';

      for (final file in _selectedImages) {
        final fileName = '${user.id}/${DateTime.now().millisecondsSinceEpoch}_${_selectedImages.indexOf(file)}.jpg';

        try {
          await supabase.storage.from(bucket).upload(
            fileName,
            file,
            fileOptions: const FileOptions(cacheControl: '3600', upsert: false),
          );
        } catch (e) {
          _showErrorSnackBar('Failed to upload one of the images: $e');
          continue;
        }

        try {
          final imageUrl = supabase.storage.from(bucket).getPublicUrl(fileName);
          uploadedUrls.add(imageUrl);
        } catch (e) {
          _showErrorSnackBar('Failed to get public URL for an image: $e');
        }
      }
    } catch (e) {
      _showErrorSnackBar('Failed to upload images: $e');
    }

    return uploadedUrls;
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
        } else if (data['locality'] != null && data['locality'].toString().isNotEmpty) {
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

    // Validate dates
    if (_startDate != null && _endDate != null) {
      if (_startDate!.isAfter(_endDate!)) {
        _showErrorSnackBar('Start date cannot be after end date');
        return;
      }
    }

    setState(() => _isSaving = true);

    try {
      final user = supabase.auth.currentUser;
      if (user == null) {
        _showErrorSnackBar('You must be logged in');
        setState(() => _isSaving = false);
        return;
      }

      List<String> imageUrls = await _uploadImages();

      if (imageUrls.isEmpty) {
        imageUrls = [''];
      }

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
        'image_url': imageUrls,
      };

      await supabase.from('travel_entries').insert(entryData);

      // Clear form
      _titleController.clear();
      _startDateController.clear();
      _endDateController.clear();
      _descController.clear();
      _startDate = null;
      _endDate = null;
      setState(() {
        _selectedImages.clear();
      });

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
                          await _pickImages();
                          setModalState(() {});
                        },
                        child: Container(
                          height: 200,
                          decoration: BoxDecoration(
                            color: Colors.grey[100],
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.grey[300]!),
                          ),
                          child: _selectedImages.isNotEmpty
                              ? Stack(
                            children: [
                              Positioned.fill(
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(vertical: 8.0),
                                  child: ListView.builder(
                                    scrollDirection: Axis.horizontal,
                                    padding: const EdgeInsets.symmetric(horizontal: 12.0),
                                    itemCount: _selectedImages.length,
                                    itemBuilder: (context, index) {
                                      final file = _selectedImages[index];
                                      return Padding(
                                        padding: const EdgeInsets.only(right: 12.0),
                                        child: Stack(
                                          children: [
                                            ClipRRect(
                                              borderRadius: BorderRadius.circular(12),
                                              child: Image.file(
                                                file,
                                                width: MediaQuery.of(context).size.width * 0.7,
                                                height: 184,
                                                fit: BoxFit.cover,
                                              ),
                                            ),
                                            Positioned(
                                              right: 8,
                                              top: 8,
                                              child: GestureDetector(
                                                onTap: () {
                                                  setModalState(() {
                                                    setState(() {
                                                      _selectedImages.removeAt(index);
                                                    });
                                                  });
                                                },
                                                child: Container(
                                                  decoration: BoxDecoration(
                                                    color: Colors.black.withOpacity(0.6),
                                                    shape: BoxShape.circle,
                                                  ),
                                                  padding: const EdgeInsets.all(6),
                                                  child: const Icon(Icons.close, color: Colors.white, size: 18),
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      );
                                    },
                                  ),
                                ),
                              ),
                              if (_selectedImages.length < 1)
                                Center(
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(Icons.add_photo_alternate_outlined, size: 60, color: Colors.grey[400]),
                                      const SizedBox(height: 12),
                                      Text('Tap to add photos', style: GoogleFonts.poppins(fontSize: 16, color: Colors.grey[600])),
                                    ],
                                  ),
                                ),
                            ],
                          )
                              : Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.add_photo_alternate_outlined, size: 60, color: Colors.grey[400]),
                              const SizedBox(height: 12),
                              Text('Tap to add photos', style: GoogleFonts.poppins(fontSize: 16, color: Colors.grey[600])),
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
                            initialDate: _startDate ?? DateTime.now(),
                            firstDate: DateTime(2000),
                            lastDate: DateTime.now(),
                          );
                          if (picked != null) {
                            setState(() {
                              _startDate = picked;
                              _startDateController.text = _formatDate(picked);
                            });
                            setModalState(() {});
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
                          // Set initial date intelligently
                          DateTime initialDate = DateTime.now();
                          if (_startDate != null) {
                            // If start date is set, use it as minimum
                            initialDate = _endDate ?? _startDate!;
                          }

                          final picked = await showDatePicker(
                            context: context,
                            initialDate: initialDate,
                            firstDate: _startDate ?? DateTime(2000),
                            lastDate: DateTime.now(),
                          );
                          if (picked != null) {
                            setState(() {
                              _endDate = picked;
                              _endDateController.text = _formatDate(picked);
                            });
                            setModalState(() {});
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
                        decoration: _inputDecoration("Share your experience here..."),
                      ),

                      const SizedBox(height: 24),

                      ElevatedButton(
                        onPressed: _isSaving ? null : () async {
                          setModalState(() {});
                          await _saveToSupabase();
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF3D8BFF),
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        child: _isSaving
                            ? const CircularProgressIndicator(color: Colors.white)
                            : Text("Add to Timeline", style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w600)),
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
      suffixIcon: const Icon(Icons.calendar_today, color: Color(0xFF3D8BFF)),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: Colors.grey[300]!),
      ),
    );
  }

  String _formatDate(DateTime d) => "${_getMonthName(d.month)} ${d.day}, ${d.year}";

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
          content: Text(msg, style: GoogleFonts.poppins()),
          backgroundColor: Colors.red),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F8FC),
      // Removed app bar since MainShell provides it
      body: Stack(
        children: [
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: _initialCenter,
              initialZoom: 13.0,
              onTap: (tapPos, point) => _fetchLocationInfo(point),
              // Allow rotation but with threshold to prevent accidental rotation
              interactionOptions: const InteractionOptions(
                flags: InteractiveFlag.all,
                rotationThreshold: 20.0, // Requires more deliberate rotation gesture
                pinchZoomThreshold: 0.5, // Makes zoom more sensitive
                pinchMoveThreshold: 40.0, // Reduces accidental movement during zoom
              ),
            ),
            children: [
              TileLayer(
                  urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                  userAgentPackageName: 'com.example.mad_project'),
              MarkerLayer(markers: [
                Marker(
                    point: _initialCenter,
                    child: const Icon(Icons.location_pin, color: Colors.blue, size: 40)),
                if (_tappedLocation != null)
                  Marker(
                      point: _tappedLocation!,
                      child: const Icon(Icons.location_on, color: Colors.red, size: 40)),
              ])
            ],
          ),
          if (_isLoading)
            Container(
              color: Colors.black.withOpacity(0.3),
              child: const Center(child: CircularProgressIndicator(color: Color(0xFF3D8BFF))),
            )
        ],
      ),
    );
  }
}