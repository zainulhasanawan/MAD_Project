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
  final TextEditingController _dateController = TextEditingController();
  final TextEditingController _descController = TextEditingController();

  final supabase = Supabase.instance.client;
  final ImagePicker _imagePicker = ImagePicker();

  File? _selectedImage;
  String? _uploadedImageUrl;

  @override
  void dispose() {
    _titleController.dispose();
    _dateController.dispose();
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

      // Create a unique filename
      final fileName = '${user.id}/${DateTime.now().millisecondsSinceEpoch}.jpg';

      // Upload to Supabase Storage
      await supabase.storage.from('Memories').upload(
        fileName,
        _selectedImage!,
        fileOptions: const FileOptions(
          cacheControl: '3600',
          upsert: false,
        ),
      );

      // Get public URL
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
        setState(() {
          _isLoading = false;
        });
        _showErrorSnackBar('Failed to fetch location info');
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      _showErrorSnackBar('Error: $e');
    }
  }

  Future<void> _saveToSupabase() async {
    if (_titleController.text.isEmpty ||
        _dateController.text.isEmpty ||
        _descController.text.isEmpty) {
      _showErrorSnackBar('Please fill in all fields');
      return;
    }

    setState(() => _isSaving = true);

    try {
      final user = supabase.auth.currentUser;
      if (user == null) {
        _showErrorSnackBar('You must be logged in to save memories');
        setState(() => _isSaving = false);
        return;
      }

      // Upload image first if selected
      String? imageUrl;
      if (_selectedImage != null) {
        imageUrl = await _uploadImage();
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
        'visit_date': _dateController.text.trim(),
        'image_url': imageUrl ?? 'assets/images/default.jpg',
      };

      await supabase.from('travel_entries').insert(entryData);

      // Clear form and image
      _titleController.clear();
      _dateController.clear();
      _descController.clear();
      _selectedImage = null;

      setState(() => _isSaving = false);

      if (mounted) Navigator.pop(context);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '✅ Memory saved! Check your timeline.',
              style: GoogleFonts.poppins(),
            ),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
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
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom,
              ),
              child: DraggableScrollableSheet(
                initialChildSize: 0.75,
                minChildSize: 0.5,
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
                        Text(
                          'Add Memory',
                          style: GoogleFonts.poppins(
                            fontSize: 24,
                            fontWeight: FontWeight.w600,
                            color: Colors.black87,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Create a new travel memory for this location',
                          style: GoogleFonts.poppins(
                            fontSize: 14,
                            color: Colors.grey[600],
                          ),
                        ),
                        const SizedBox(height: 24),

                        // Image Picker Section
                        Text(
                          'Photo',
                          style: GoogleFonts.poppins(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: Colors.black87,
                          ),
                        ),
                        const SizedBox(height: 8),
                        GestureDetector(
                          onTap: () async {
                            await _pickImage();
                            setModalState(() {}); // Update bottom sheet
                          },
                          child: Container(
                            height: 200,
                            decoration: BoxDecoration(
                              color: Colors.grey[100],
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: Colors.grey[300]!),
                            ),
                            child: _selectedImage != null
                                ? Stack(
                              children: [
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(12),
                                  child: Image.file(
                                    _selectedImage!,
                                    width: double.infinity,
                                    height: 200,
                                    fit: BoxFit.cover,
                                  ),
                                ),
                                Positioned(
                                  top: 8,
                                  right: 8,
                                  child: CircleAvatar(
                                    backgroundColor: Colors.red,
                                    radius: 16,
                                    child: IconButton(
                                      padding: EdgeInsets.zero,
                                      icon: const Icon(
                                        Icons.close,
                                        size: 18,
                                        color: Colors.white,
                                      ),
                                      onPressed: () {
                                        setState(() => _selectedImage = null);
                                        setModalState(() {});
                                      },
                                    ),
                                  ),
                                ),
                              ],
                            )
                                : Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.add_photo_alternate_outlined,
                                  size: 60,
                                  color: Colors.grey[400],
                                ),
                                const SizedBox(height: 12),
                                Text(
                                  'Tap to add photo',
                                  style: GoogleFonts.poppins(
                                    fontSize: 16,
                                    color: Colors.grey[600],
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Optional',
                                  style: GoogleFonts.poppins(
                                    fontSize: 12,
                                    color: Colors.grey[400],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),

                        const SizedBox(height: 20),

                        // Location Info Card
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: const Color(0xFF3D8BFF).withOpacity(0.1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            children: [
                              const Icon(
                                Icons.location_on,
                                color: Color(0xFF3D8BFF),
                                size: 24,
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Selected Location',
                                      style: GoogleFonts.poppins(
                                        fontSize: 12,
                                        color: Colors.grey[700],
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      '${_tappedLocation!.latitude.toStringAsFixed(4)}, ${_tappedLocation!.longitude.toStringAsFixed(4)}',
                                      style: GoogleFonts.poppins(
                                        fontSize: 13,
                                        color: Colors.black87,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(height: 20),

                        // Title Field
                        Text(
                          'Title',
                          style: GoogleFonts.poppins(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: Colors.black87,
                          ),
                        ),
                        const SizedBox(height: 8),
                        TextField(
                          controller: _titleController,
                          decoration: InputDecoration(
                            hintText: 'e.g., Tokyo, Japan',
                            hintStyle: GoogleFonts.poppins(color: Colors.grey[400]),
                            filled: true,
                            fillColor: Colors.grey[50],
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(color: Colors.grey[300]!),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(color: Colors.grey[300]!),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: const BorderSide(
                                  color: Color(0xFF3D8BFF), width: 2),
                            ),
                          ),
                          style: GoogleFonts.poppins(),
                        ),

                        const SizedBox(height: 16),

                        // Date Field
                        Text(
                          'Date',
                          style: GoogleFonts.poppins(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: Colors.black87,
                          ),
                        ),
                        const SizedBox(height: 8),
                        TextField(
                          controller: _dateController,
                          decoration: InputDecoration(
                            hintText: 'e.g., Oct 15, 2023',
                            hintStyle: GoogleFonts.poppins(color: Colors.grey[400]),
                            filled: true,
                            fillColor: Colors.grey[50],
                            suffixIcon: IconButton(
                              icon: const Icon(Icons.calendar_today,
                                  color: Color(0xFF3D8BFF)),
                              onPressed: () async {
                                final DateTime? picked = await showDatePicker(
                                  context: context,
                                  initialDate: DateTime.now(),
                                  firstDate: DateTime(2000),
                                  lastDate: DateTime.now(),
                                );
                                if (picked != null) {
                                  _dateController.text =
                                  '${_getMonthName(picked.month)} ${picked.day}, ${picked.year}';
                                }
                              },
                            ),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(color: Colors.grey[300]!),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(color: Colors.grey[300]!),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: const BorderSide(
                                  color: Color(0xFF3D8BFF), width: 2),
                            ),
                          ),
                          style: GoogleFonts.poppins(),
                        ),

                        const SizedBox(height: 16),

                        // Description Field
                        Text(
                          'Description',
                          style: GoogleFonts.poppins(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: Colors.black87,
                          ),
                        ),
                        const SizedBox(height: 8),
                        TextField(
                          controller: _descController,
                          maxLines: 4,
                          decoration: InputDecoration(
                            hintText: 'Share your experience at this location...',
                            hintStyle: GoogleFonts.poppins(color: Colors.grey[400]),
                            filled: true,
                            fillColor: Colors.grey[50],
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(color: Colors.grey[300]!),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(color: Colors.grey[300]!),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: const BorderSide(
                                  color: Color(0xFF3D8BFF), width: 2),
                            ),
                          ),
                          style: GoogleFonts.poppins(),
                        ),

                        const SizedBox(height: 24),

                        // Add to Timeline Button
                        ElevatedButton(
                          onPressed: _isSaving ? null : _saveToSupabase,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF3D8BFF),
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            elevation: 0,
                          ),
                          child: _isSaving
                              ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(
                                  Colors.white),
                            ),
                          )
                              : Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.add_circle_outline, size: 20),
                              const SizedBox(width: 8),
                              Text(
                                'Add to Timeline',
                                style: GoogleFonts.poppins(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(height: 12),

                        // Cancel Button
                        OutlinedButton(
                          onPressed: () {
                            _titleController.clear();
                            _dateController.clear();
                            _descController.clear();
                            _selectedImage = null;
                            Navigator.pop(context);
                          },
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            side: BorderSide(color: Colors.grey[300]!),
                          ),
                          child: Text(
                            'Cancel',
                            style: GoogleFonts.poppins(
                              fontSize: 16,
                              fontWeight: FontWeight.w500,
                              color: Colors.grey[700],
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            );
          },
        );
      },
    );
  }

  String _getMonthName(int month) {
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec'
    ];
    return months[month - 1];
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, style: GoogleFonts.poppins()),
        backgroundColor: Colors.red,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F8FC),
      appBar: AppBar(
        title: Text(
          "Map",
          style: GoogleFonts.poppins(
            color: Colors.black87,
            fontWeight: FontWeight.w600,
          ),
        ),
        centerTitle: true,
        elevation: 0,
        backgroundColor: Colors.white,
      ),
      body: Stack(
        children: [
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: _initialCenter,
              initialZoom: 13.0,
              onTap: (tapPosition, point) {
                debugPrint(
                    "User tapped on map at: ${point.latitude}, ${point.longitude}");
                _fetchLocationInfo(point);
              },
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.example.mad_project',
              ),
              MarkerLayer(
                markers: [
                  Marker(
                    point: _initialCenter,
                    child: const Icon(
                      Icons.location_pin,
                      color: Colors.blue,
                      size: 40,
                    ),
                  ),
                  if (_tappedLocation != null)
                    Marker(
                      point: _tappedLocation!,
                      child: const Icon(
                        Icons.location_on,
                        color: Colors.red,
                        size: 40,
                      ),
                    ),
                ],
              ),
            ],
          ),
          if (_isLoading)
            Container(
              color: Colors.black.withOpacity(0.3),
              child: const Center(
                child: CircularProgressIndicator(
                  color: Color(0xFF3D8BFF),
                ),
              ),
            ),
        ],
      ),
    );
  }
}