import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'trip_detail_screen.dart';

class TimelineScreen extends StatefulWidget {
  const TimelineScreen({Key? key}) : super(key: key);

  @override
  State<TimelineScreen> createState() => _TimelineScreenState();
}

class _TimelineScreenState extends State<TimelineScreen> {
  List<Map<String, dynamic>> trips = [
    {
      "title": "Tokyo, Japan",
      "date": "Oct 15, 2023",
      "desc": "Explored vibrant Shibuya crossing and enjoyed delicious ramen.",
      "image": "assets/images/tokyo.jpg"
    },
    {
      "title": "Paris, France",
      "date": "Sep 01, 2023",
      "desc": "Walked along the Seine, saw the Louvre. Indulged in croissants.",
      "image": "assets/images/paris.jpg"
    },
    {
      "title": "Rome, Italy",
      "date": "Aug 10, 2023",
      "desc": "Visited ancient Roman ruins, tossed a coin in the Trevi Fountain.",
      "image": "assets/images/rome.jpg"
    },
    {
      "title": "New York City, USA",
      "date": "Jul 20, 2023",
      "desc": "Explored Times Square, walked through Central Park, and saw Broadway.",
      "image": "assets/images/nyc.jpg"
    },
    {
      "title": "Sydney, Australia",
      "date": "Jun 05, 2023",
      "desc": "Relaxed on Bondi Beach, marvelled at the Opera House.",
      "image": "assets/images/sydney.jpg"
    },
  ];

  void _addNewMemory(Map<String, dynamic> newTrip) {
    setState(() {
      // Add the new trip to the beginning of the list
      trips.insert(0, newTrip);
    });
  }

  Future<void> _navigateToMap() async {
    // Navigate to map screen and wait for result
    final result = await Navigator.pushNamed(context, '/map');

    // If we got data back, add it to the timeline
    if (result != null && result is Map<String, dynamic>) {
      _addNewMemory(result);
    }
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
            tooltip: 'Add from Map',
          ),
        ],
      ),
      body: trips.isEmpty
          ? Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.explore_off,
              size: 80,
              color: Colors.grey[300],
            ),
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
      )
          : ListView.builder(
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
                  // Image Section
                  ClipRRect(
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(14),
                      topRight: Radius.circular(14),
                    ),
                    child: trip["image"] != null
                        ? Image.asset(
                      trip["image"]!,
                      width: double.infinity,
                      height: 180,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) {
                        return _buildPlaceholderImage();
                      },
                    )
                        : _buildPlaceholderImage(),
                  ),
                  // Content Section
                  Padding(
                    padding: const EdgeInsets.all(12.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                trip["title"]!,
                                style: GoogleFonts.poppins(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 16,
                                ),
                              ),
                            ),
                            if (index == 0) // Show "New" badge for latest entry
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF3D8BFF),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(
                                  'NEW',
                                  style: GoogleFonts.poppins(
                                    color: Colors.white,
                                    fontSize: 10,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            const Icon(
                              Icons.calendar_today,
                              size: 12,
                              color: Colors.grey,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              trip["date"]!,
                              style: GoogleFonts.poppins(
                                color: Colors.grey,
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          trip["desc"]!,
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
      ),
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
        child: Icon(
          Icons.photo_camera,
          size: 60,
          color: Colors.white70,
        ),
      ),
    );
  }
}