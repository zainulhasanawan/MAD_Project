import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class TimelineScreen extends StatelessWidget {
  const TimelineScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final List<Map<String, String>> trips = [
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

    return Scaffold(
      backgroundColor: const Color(0xFFF8F8FC),
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.white,
        centerTitle: true,
        title: Text(
          "Travel Timeline",
          style: GoogleFonts.poppins(
            color: Colors.black87,
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),

      body: ListView.builder(
        padding: const EdgeInsets.all(12),
        itemCount: trips.length,
        itemBuilder: (context, index) {
          final trip = trips[index];
          return Container(
            margin: const EdgeInsets.only(bottom: 20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              boxShadow: [
                BoxShadow(
                  color: Colors.black12.withOpacity(0.05),
                  blurRadius: 8,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 📸 Larger image
                ClipRRect(
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(14),
                    topRight: Radius.circular(14),
                  ),
                  child: Image.asset(
                    trip["image"]!,
                    width: double.infinity,
                    height: 180, // ⬅️ increased image height
                    fit: BoxFit.cover,
                  ),
                ),

                Padding(
                  padding: const EdgeInsets.all(12.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        trip["title"]!,
                        style: GoogleFonts.poppins(
                          fontWeight: FontWeight.w600,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        trip["date"]!,
                        style: GoogleFonts.poppins(
                          color: Colors.grey.shade600,
                          fontSize: 13,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        trip["desc"]!,
                        style: GoogleFonts.poppins(
                          color: Colors.black87,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),

      bottomNavigationBar: BottomNavigationBar(
        currentIndex: 1,
        onTap: (index) {
          // TODO: switch pages
        },
        type: BottomNavigationBarType.fixed,
        selectedItemColor: const Color(0xFF3D8BFF),
        unselectedItemColor: Colors.grey,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home_outlined), label: 'Map'),
          BottomNavigationBarItem(icon: Icon(Icons.timeline), label: 'Timeline'),
          BottomNavigationBarItem(icon: Icon(Icons.bar_chart_outlined), label: 'Stats'),
          BottomNavigationBarItem(icon: Icon(Icons.person_outline), label: 'Profile'),
        ],
      ),
    );
  }
}
