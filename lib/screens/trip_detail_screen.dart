import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class TripDetailScreen extends StatelessWidget {
  final Map<String, dynamic> trip;

  const TripDetailScreen({Key? key, required this.trip}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final String from = "Oct 5, 2023";
    final String to = "Oct 12, 2023";
    final String duration = "8 days";

    return Scaffold(
      backgroundColor: const Color(0xFFF8F8FC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Colors.black87),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          trip['title'] ?? 'Trip Details',
          style: GoogleFonts.poppins(
            color: Colors.black87,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Image with error handling
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: trip['image'] != null
                  ? Image.asset(
                trip['image']!,
                width: double.infinity,
                height: 220,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) {
                  return _buildPlaceholderImage();
                },
              )
                  : _buildPlaceholderImage(),
            ),
            const SizedBox(height: 14),

            // Visit details card
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Visit Details',
                    style: GoogleFonts.poppins(
                      fontWeight: FontWeight.w600,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 10),
                  _detailRow(Icons.calendar_today, 'Date', trip['date'] ?? 'N/A'),
                  const SizedBox(height: 6),
                  _detailRow(Icons.calendar_today_outlined, 'To', to),
                  const SizedBox(height: 6),
                  _detailRow(Icons.access_time, 'Duration', duration),
                  // Show coordinates if available
                  if (trip['latitude'] != null && trip['longitude'] != null) ...[
                    const SizedBox(height: 6),
                    _detailRow(
                      Icons.location_on,
                      'Location',
                      '${trip['latitude']?.toStringAsFixed(4)}, ${trip['longitude']?.toStringAsFixed(4)}',
                    ),
                  ],
                ],
              ),
            ),

            const SizedBox(height: 16),

            // Notes
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'My Notes',
                        style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
                      ),
                      IconButton(
                        icon: const Icon(
                          Icons.edit,
                          color: Color(0xFF3D8BFF),
                        ),
                        onPressed: () {},
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    trip['desc'] ?? 'No description available',
                    style: GoogleFonts.poppins(fontSize: 14, height: 1.5),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // Photo memories (stub)
            Text(
              'Photo Memories',
              style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            SizedBox(
              height: 100,
              child: ListView(
                scrollDirection: Axis.horizontal,
                children: [
                  const SizedBox(width: 4),
                  _photoTileAdd(),
                  const SizedBox(width: 8),
                  if (trip['image'] != null) ...[
                    _photoTile(trip['image']!),
                    const SizedBox(width: 8),
                    _photoTile(trip['image']!),
                  ],
                ],
              ),
            ),

            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _detailRow(IconData icon, String label, String value) {
    return Row(
      children: [
        Icon(icon, color: const Color(0xFF3D8BFF), size: 18),
        const SizedBox(width: 8),
        Text(
          '$label: ',
          style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
        ),
        Expanded(
          child: Text(
            value,
            style: GoogleFonts.poppins(),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  Widget _photoTile(String path) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(10),
      child: Image.asset(
        path,
        width: 120,
        height: 100,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) {
          return Container(
            width: 120,
            height: 100,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10),
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  const Color(0xFF3D8BFF).withOpacity(0.7),
                  const Color(0xFF3D8BFF).withOpacity(0.4),
                ],
              ),
            ),
            child: const Icon(
              Icons.photo,
              size: 40,
              color: Colors.white70,
            ),
          );
        },
      ),
    );
  }

  Widget _photoTileAdd() {
    return ClipRRect(
      borderRadius: BorderRadius.circular(10),
      child: Container(
        width: 120,
        height: 100,
        color: Colors.grey.shade200,
        child: const Icon(
          Icons.add_a_photo_outlined,
          size: 36,
          color: Colors.grey,
        ),
      ),
    );
  }

  Widget _buildPlaceholderImage() {
    return Container(
      width: double.infinity,
      height: 220,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            const Color(0xFF3D8BFF).withOpacity(0.7),
            const Color(0xFF3D8BFF).withOpacity(0.4),
          ],
        ),
      ),
      child: const Center(
        child: Icon(
          Icons.photo_camera,
          size: 60,
          color: Colors.white70,
        ),
      ),
    );
  }
}