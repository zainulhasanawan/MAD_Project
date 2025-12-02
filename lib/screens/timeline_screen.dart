import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:cached_network_image/cached_network_image.dart';
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
    setState(() => isLoading = true);

    try {
      final user = supabase.auth.currentUser;
      if (user == null) {
        setState(() {
          trips = [];
          isLoading = false;
        });
        return;
      }

      final response = await supabase
          .from('travel_entries')
          .select()
          .eq('user_id', user.id)
          .order('id', ascending: false);

      if (response == null) {
        setState(() {
          trips = [];
          isLoading = false;
        });
        return;
      }

      List<Map<String, dynamic>> formatted = [];

      for (final dynamic row in response) {
        final String? startDate =
        (row['visit_start_date'] is String) ? row['visit_start_date'] : null;
        final String? endDate =
        (row['visit_end_date'] is String) ? row['visit_end_date'] : null;

        String dateRange = '';
        if (startDate != null && startDate.isNotEmpty) {
          if (endDate != null && endDate.isNotEmpty && endDate != startDate) {
            dateRange = '$startDate – $endDate';
          } else {
            dateRange = startDate;
          }
        }

        List<dynamic>? imgsDynamic;
        try {
          imgsDynamic =
          (row['image_url'] is List) ? List<dynamic>.from(row['image_url']) : null;
        } catch (_) {
          imgsDynamic = null;
        }

        final placeholderCandidates = {'', 'null', 'error', 'placeholder'};
        List<String> imgs = [];
        if (imgsDynamic != null) {
          for (final item in imgsDynamic) {
            if (item == null) continue;
            final s = item.toString().trim();
            if (s.isEmpty) continue;
            if (placeholderCandidates.contains(s.toLowerCase())) continue;
            if (!s.toLowerCase().startsWith('http')) continue;
            imgs.add(s);
          }
        }

        String? coverImage = imgs.isNotEmpty ? imgs.first : null;

        formatted.add({
          "id": row['id'],
          "title": row['title'],
          "desc": row['description'],
          "image_url": imgs,
          "cover_image": coverImage,
          "lat": row['latitude'],
          "lng": row['longitude'],
          "date_range": dateRange,
          "visit_start_date": startDate,
          "visit_end_date": endDate,
        });
      }

      if (mounted) {
        setState(() {
          trips = formatted;
          isLoading = false;
        });
      }
    } catch (e) {
      debugPrint("Error loading trips: $e");
      if (mounted) setState(() => isLoading = false);
    }
  }

  // --------------------------
  // DELETE TRIP FUNCTIONALITY
  // --------------------------
  Future<void> _deleteTrip(dynamic tripId, String tripTitle) async { // Changed to dynamic
    // Show confirmation dialog
    final shouldDelete = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          'Delete Memory',
          style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
        ),
        content: Text(
          'Are you sure you want to delete "$tripTitle"?\nThis action cannot be undone.',
          style: GoogleFonts.poppins(),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(
              'Cancel',
              style: GoogleFonts.poppins(color: Colors.grey[600]),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(
              'Delete',
              style: GoogleFonts.poppins(color: Colors.red, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );

    if (shouldDelete != true) return;

    try {
      // Show loading
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
              const SizedBox(width: 12),
              Text('Deleting memory...', style: GoogleFonts.poppins()),
            ],
          ),
          backgroundColor: const Color(0xFF3D8BFF),
        ),
      );

      // Delete from Supabase - Handle both String and int IDs
      await supabase
          .from('travel_entries')
          .delete()
          .eq('id', tripId);

      // Remove from local list
      setState(() {
        trips.removeWhere((trip) => trip['id'] == tripId);
      });

      // Show success message
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.check_circle, color: Colors.white, size: 20),
              const SizedBox(width: 8),
              Text('Memory deleted successfully', style: GoogleFonts.poppins()),
            ],
          ),
          backgroundColor: Colors.green,
          duration: const Duration(seconds: 2),
        ),
      );
    } catch (e) {
      // Show error message
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.error_outline, color: Colors.white, size: 20),
              const SizedBox(width: 8),
              Text('Failed to delete: $e', style: GoogleFonts.poppins()),
            ],
          ),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 3),
        ),
      );
      debugPrint("Error deleting trip: $e");
    }
  }

  Future<void> _navigateToMap() async {
    final bool? memoryAdded = await Navigator.pushNamed(context, '/map') as bool?;
    if (memoryAdded == true) {
      await _loadTripsFromSupabase();
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
          ),
        ],
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : trips.isEmpty
          ? _buildEmptyState()
          : RefreshIndicator(
        onRefresh: _loadTripsFromSupabase,
        child: _buildTimelineList(),
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

  Widget _buildTimelineList() {
    return ListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: trips.length,
      itemBuilder: (context, index) {
        final trip = trips[index];
        final tripId = trip['id']; // Don't cast to int - keep as dynamic
        final tripTitle = trip['title']?.toString() ?? 'Untitled'; // Ensure string

        return Dismissible(
          key: Key('trip_${tripId.toString()}'), // Convert to string for key
          direction: DismissDirection.endToStart,
          background: Container(
            decoration: BoxDecoration(
              color: Colors.red,
              borderRadius: BorderRadius.circular(14),
            ),
            alignment: Alignment.centerRight,
            padding: const EdgeInsets.only(right: 20),
            child: const Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Icon(Icons.delete, color: Colors.white, size: 24),
                SizedBox(width: 8),
                Text(
                  'Delete',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                SizedBox(width: 12),
              ],
            ),
          ),
          confirmDismiss: (direction) async {
            // Show confirmation dialog when swiped
            final shouldDelete = await showDialog<bool>(
              context: context,
              builder: (context) => AlertDialog(
                title: Text(
                  'Delete Memory',
                  style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
                ),
                content: Text(
                  'Are you sure you want to delete "$tripTitle"?',
                  style: GoogleFonts.poppins(),
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(false),
                    child: Text(
                      'Cancel',
                      style: GoogleFonts.poppins(color: Colors.grey[600]),
                    ),
                  ),
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(true),
                    child: Text(
                      'Delete',
                      style: GoogleFonts.poppins(color: Colors.red, fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              ),
            );
            return shouldDelete ?? false;
          },
          onDismissed: (direction) {
            // Actually delete the trip
            _deleteTrip(tripId, tripTitle);
          },
          child: GestureDetector(
            onTap: () async {
              final changed = await Navigator.push<bool>(
                context,
                MaterialPageRoute(
                  builder: (_) => TripDetailScreen(trip: trip),
                ),
              );

              if (changed == true) {
                await _loadTripsFromSupabase();
              }
            },
            onLongPress: () {
              // Show delete option on long press
              showModalBottomSheet(
                context: context,
                shape: const RoundedRectangleBorder(
                  borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
                ),
                builder: (context) => Container(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 40,
                        height: 4,
                        decoration: BoxDecoration(
                          color: Colors.grey[300],
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                      const SizedBox(height: 20),
                      ListTile(
                        leading: const Icon(Icons.delete, color: Colors.red),
                        title: Text(
                          'Delete Memory',
                          style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
                        ),
                        subtitle: Text(
                          'Remove "$tripTitle" from your timeline',
                          style: GoogleFonts.poppins(color: Colors.grey[600]),
                        ),
                        onTap: () {
                          Navigator.pop(context);
                          _deleteTrip(tripId, tripTitle);
                        },
                      ),
                      ListTile(
                        leading: const Icon(Icons.edit, color: Color(0xFF3D8BFF)),
                        title: Text(
                          'Edit Details',
                          style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
                        ),
                        onTap: () {
                          Navigator.pop(context);
                          Navigator.push<bool>(
                            context,
                            MaterialPageRoute(
                              builder: (_) => TripDetailScreen(trip: trip),
                            ),
                          ).then((changed) {
                            if (changed == true) {
                              _loadTripsFromSupabase();
                            }
                          });
                        },
                      ),
                      ListTile(
                        leading: const Icon(Icons.cancel, color: Colors.grey),
                        title: Text(
                          'Cancel',
                          style: GoogleFonts.poppins(),
                        ),
                        onTap: () => Navigator.pop(context),
                      ),
                    ],
                  ),
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
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
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
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                trip["title"]?.toString() ?? "Unknown Location", // Ensure string
                                style: GoogleFonts.poppins(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 16,
                                ),
                              ),
                            ),
                            // Small delete icon in corner
                            IconButton(
                              icon: const Icon(Icons.more_vert, size: 20, color: Colors.grey),
                              onPressed: () {
                                _deleteTrip(tripId, tripTitle);
                              },
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(),
                            ),
                          ],
                        ),
                        if ((trip["date_range"]?.toString() ?? '').isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Row(
                              children: [
                                const Icon(Icons.calendar_today,
                                    size: 12, color: Colors.grey),
                                const SizedBox(width: 6),
                                Text(
                                  trip["date_range"]?.toString() ?? '', // Ensure string
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
                          trip["desc"]?.toString() ?? "", // Ensure string
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
          ),
        );
      },
    );
  }

  ///     USE CACHED NETWORK IMAGE
  Widget _buildCoverImage(String? imageUrl) {
    if (imageUrl != null && imageUrl.startsWith("http")) {
      return CachedNetworkImage(
        imageUrl: imageUrl,
        width: double.infinity,
        height: 180,
        fit: BoxFit.cover,
        memCacheWidth: 700,
        memCacheHeight: 700,
        placeholder: (_, __) => _buildPlaceholderImage(),
        errorWidget: (_, __, ___) => _buildPlaceholderImage(),
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