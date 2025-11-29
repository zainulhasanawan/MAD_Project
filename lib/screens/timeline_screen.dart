import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'trip_detail_screen.dart';

class TimelineScreen extends StatefulWidget {
  const TimelineScreen({Key? key}) : super(key: key);

  @override
  State<TimelineScreen> createState() => _TimelineScreenState();
}

class _TimelineScreenState extends State<TimelineScreen> {
  final supabase = Supabase.instance.client;

  List<Map<String, dynamic>> trips = [];
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadTripsFromSupabase();
  }

  Future<void> _loadTripsFromSupabase() async {
    try {
      final userId = supabase.auth.currentUser!.id;

      final response = await supabase
          .from('travel_entries')
          .select()
          .eq('user_id', userId)
          .order('id', ascending: false);

      List<Map<String, dynamic>> formatted = [];

      for (final row in response) {
        final String? startDate = row['visit_start_date'];
        final String? endDate = row['visit_end_date'];

        String dateRange = '';

        if (startDate != null && startDate.isNotEmpty) {
          if (endDate != null && endDate.isNotEmpty && endDate != startDate) {
            dateRange = '$startDate – $endDate';
          } else {
            dateRange = startDate;
          }
        }

        /// 🔥 FIX: image_url is ARRAY, not single string
        List<dynamic>? imgs = row['image_url'];

        /// 🔥 Pick first image for cover photo
        String? coverImage =
        (imgs != null && imgs.isNotEmpty) ? imgs.first.toString() : null;

        formatted.add({
          "id": row['id'],
          "title": row['title'],
          "desc": row['description'],
          "image_url": imgs,       // full list for detail screen
          "cover_image": coverImage,
          "lat": row['latitude'],
          "lng": row['longitude'],
          "date_range": dateRange,
          "visit_start_date": startDate,
          "visit_end_date": endDate,
        });
      }

      setState(() {
        trips = formatted;
        isLoading = false;
      });
    } catch (e) {
      debugPrint("Error loading trips: $e");
      setState(() => isLoading = false);
    }
  }

  Future<void> _navigateToMap() async {
    final result = await Navigator.pushNamed(context, '/map');
    if (result != null) _loadTripsFromSupabase();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F8FC),
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.white,
        centerTitle: true,
        title: Text(
          'Travel Timeline',
          style: GoogleFonts.poppins(
            color: Colors.black87,
            fontWeight: FontWeight.w600,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.map, color: Color(0xFF3D8BFF)),
            onPressed: _navigateToMap,
          ),
        ],
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : trips.isEmpty
          ? _buildEmptyState()
          : _buildTimelineList(),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _navigateToMap,
        backgroundColor: const Color(0xFF3D8BFF),
        icon: const Icon(Icons.add_location_alt),
        label: Text(
          'Add Memory',
          style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
        ),
      ),
    );
  }

  Widget _buildTimelineList() {
    return ListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: trips.length,
      itemBuilder: (context, index) {
        final trip = trips[index];

        return GestureDetector(
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => TripDetailScreen(trip: trip),
              ),
            );
          },
          child: Container(
            margin: const EdgeInsets.only(bottom: 20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              boxShadow: [
                BoxShadow(
                  color: Colors.black12.withOpacity(0.05),
                  blurRadius: 8,
                  offset: const Offset(0, 3),
                )
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                /// 🔥 Cover image (first image)
                ClipRRect(
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(14),
                    topRight: Radius.circular(14),
                  ),
                  child: _buildCoverImage(trip["cover_image"]),
                ),

                Padding(
                  padding: const EdgeInsets.all(12.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        trip["title"] ?? "Unknown Location",
                        style: GoogleFonts.poppins(
                          fontWeight: FontWeight.w600,
                          fontSize: 16,
                        ),
                      ),

                      if ((trip["date_range"] ?? '').isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Row(
                            children: [
                              const Icon(Icons.calendar_today,
                                  size: 12, color: Colors.grey),
                              const SizedBox(width: 6),
                              Text(
                                trip["date_range"],
                                style: GoogleFonts.poppins(
                                  color: Colors.grey,
                                  fontSize: 13,
                                ),
                              ),
                            ],
                          ),
                        ),

                      const SizedBox(height: 8),
                      Text(
                        trip["desc"] ?? "",
                        style: GoogleFonts.poppins(
                          color: Colors.black87,
                          fontSize: 13,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                )
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildCoverImage(String? imageUrl) {
    if (imageUrl != null && imageUrl.startsWith("http")) {
      return Image.network(
        imageUrl,
        width: double.infinity,
        height: 180,
        fit: BoxFit.cover,
        loadingBuilder: (context, child, progress) {
          if (progress == null) return child;
          return _buildPlaceholderImage();
        },
        errorBuilder: (_, __, ___) => _buildPlaceholderImage(),
      );
    }

    return _buildPlaceholderImage();
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.explore_off, size: 80, color: Colors.grey[300]),
          const SizedBox(height: 16),
          Text(
            'No memories yet',
            style: GoogleFonts.poppins(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: Colors.grey[400],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Tap the map icon to add your first memory',
            style: GoogleFonts.poppins(
              fontSize: 14,
              color: Colors.grey[400],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPlaceholderImage() {
    return Container(
      width: double.infinity,
      height: 180,
      decoration: BoxDecoration(
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
        child: Icon(Icons.photo_camera, size: 60, color: Colors.white70),
      ),
    );
  }
}
