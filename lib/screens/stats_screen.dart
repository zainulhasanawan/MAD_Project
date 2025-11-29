import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:fl_chart/fl_chart.dart';

class StatsScreen extends StatefulWidget {
  const StatsScreen({Key? key}) : super(key: key);

  @override
  State<StatsScreen> createState() => _StatsScreenState();
}

class _StatsScreenState extends State<StatsScreen> {
  // Sample summary numbers
  final int placesVisited = 150;
  final int countriesExplored = 25;
  final String distanceTraveled = '85,000 km';

  // sample bar data (monthly trips)
  final List<int> monthlyTrips = [1, 2, 3, 2, 4, 5, 3, 2, 3, 2, 1, 2];

  // sample pie data (countries distribution)
  final Map<String, double> countries = {
    'France': 25,
    'Italy': 20,
    'Japan': 30,
    'USA': 15,
    'Canada': 10,
  };

  // sample line data (distance trend)
  final List<double> distanceTrend = [0.8, 1.2, 2.3, 1.8, 2.7, 2.2]; // in 'k' (thousands)

  @override
  Widget build(BuildContext context) {
    final themeBlue = const Color(0xFF3D8BFF);
    return Scaffold(
      backgroundColor: const Color(0xFFF8F8FC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        title: Text(
          'Statistics',
          style: GoogleFonts.poppins(
            color: Colors.black87,
            fontWeight: FontWeight.w600,
            fontSize: 18,
          ),
        ),
      ),
      body: SafeArea(
          child: LayoutBuilder(builder: (context, constraints) {
            final double availH = constraints.maxHeight;
            final double availW = constraints.maxWidth;

            // chart heights scale with available height
            final double barChartH = (availH * 0.20).clamp(110.0, 200.0);
            final double pieChartH = (availH * 0.18).clamp(100.0, 160.0);
            final double lineChartH = (availH * 0.28).clamp(140.0, 260.0);

            // For small widths, switch stat cards to vertical stack using Wrap
            final bool narrow = availW < 380;

            return SingleChildScrollView(
              padding: EdgeInsets.fromLTRB(16, 16, 16, kBottomNavigationBarHeight + 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // --- Stat cards: use Wrap so they can wrap on small widths ---
                  Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: [
                      SizedBox(
                        width: double.infinity,
                        child: _statCard('Places Visited', placesVisited.toString(), Icons.place, Colors.orange),
                      ),
                      SizedBox(
                        width: double.infinity,
                        child: _statCard('Countries Explored', countriesExplored.toString(), Icons.public, Colors.green),
                      ),
                      SizedBox(
                        width: double.infinity,
                        child: _statCard('Distance Traveled', distanceTraveled, Icons.trending_up, Colors.pink),
                      ),
                      // placeholder for alignment (keeps grid feel on larger widths)
                      if (!narrow)
                        SizedBox(
                          width: (availW - 12) / 2,
                          child: const SizedBox.shrink(),
                        ),
                    ],
                  ),

                  const SizedBox(height: 18),

                  // --- Travel summary (with bar chart) ---
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: const Color(0xFFEFF6FF),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Travel Summary 2024', style: GoogleFonts.poppins(fontWeight: FontWeight.w700, fontSize: 16)),
                        const SizedBox(height: 10),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            _summaryMini('Trips:', '18'),
                            _summaryMini('Days Traveled:', '60'),
                          ],
                        ),
                        const SizedBox(height: 12),
                        const Divider(thickness: 1, height: 6, color: Colors.black12),
                        const SizedBox(height: 12),
                        SizedBox(height: barChartH, child: _buildBarChart()),
                      ],
                    ),
                  ),

                  const SizedBox(height: 18),

                  // --- Pie chart + Legend ---
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12)),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Countries Explored', style: GoogleFonts.poppins(fontWeight: FontWeight.w700, fontSize: 16)),
                        const SizedBox(height: 12),
                        SizedBox(
                          height: pieChartH,
                          child: Row(
                            children: [
                              // Pie chart should flex to available width
                              Flexible(
                                flex: 3,
                                child: Padding(
                                  padding: const EdgeInsets.only(right: 8),
                                  child: _buildPieChart(),
                                ),
                              ),

                              // Legend: allow scrolling vertically if there are many items, and wrap text
                              Flexible(
                                flex: 4,
                                child: SingleChildScrollView(
                                  physics: const BouncingScrollPhysics(),
                                  child: _buildCountriesLegend(maxWidth: availW * 0.45),
                                ),
                              ),
                            ],
                          ),
                        )
                      ],
                    ),
                  ),

                  const SizedBox(height: 18),

                  // --- Line chart ---
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12)),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Distance Traveled Trend', style: GoogleFonts.poppins(fontWeight: FontWeight.w700, fontSize: 16)),
                        const SizedBox(height: 12),
                        SizedBox(height: lineChartH, child: _buildLineChart()),
                      ],
                    ),
                  ),

                  const SizedBox(height: 24),
                ],
              ),
            );
          },
          )),
    );
  }

  Widget _statCard(String title, String value, IconData icon, Color iconColor) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12)),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(color: iconColor.withOpacity(0.12), borderRadius: BorderRadius.circular(8)),
            child: Icon(icon, color: iconColor, size: 20),
          ),
          const SizedBox(width: 12),
          // Use Expanded so long titles/values wrap instead of overflowing
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(title, style: GoogleFonts.poppins(fontSize: 13, color: Colors.grey.shade700)),
              const SizedBox(height: 6),
              Text(value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.poppins(fontWeight: FontWeight.w700, fontSize: 18)),
            ]),
          ),
        ],
      ),
    );
  }

  Widget _summaryMini(String label, String value) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(label, style: GoogleFonts.poppins(color: Colors.grey.shade700)),
      const SizedBox(height: 6),
      Text(value, style: GoogleFonts.poppins(fontWeight: FontWeight.w700, fontSize: 16)),
    ]);
  }

  // -------- Bar chart ----------
  Widget _buildBarChart() {
    final bars = List.generate(monthlyTrips.length, (i) {
      return BarChartGroupData(x: i, barRods: [
        BarChartRodData(toY: monthlyTrips[i].toDouble(), color: const Color(0xFF4F9AFF), width: 12)
      ]);
    });

    return BarChart(
      BarChartData(
        barGroups: bars,
        alignment: BarChartAlignment.spaceAround,
        titlesData: FlTitlesData(
          show: true,
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 28,
              getTitlesWidget: (value, meta) {
                const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
                final idx = value.toInt();
                final text = (idx >= 0 && idx < months.length) ? months[idx] : '';
                return Text(text, style: GoogleFonts.poppins(fontSize: 10));
              },
            ),
          ),
          leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
          topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
        ),
        gridData: FlGridData(show: false),
        borderData: FlBorderData(show: false),
        maxY: (monthlyTrips.reduce((a, b) => a > b ? a : b).toDouble() + 2),
      ),
    );
  }

  // -------- Pie chart ----------
  Widget _buildPieChart() {
    final sections = <PieChartSectionData>[];
    final colors = [Colors.blue, Colors.orange, Colors.green, Colors.purple, Colors.amber];
    final entries = countries.entries.toList();
    for (var i = 0; i < entries.length; i++) {
      final e = entries[i];
      sections.add(PieChartSectionData(
        value: e.value,
        title: '${e.value.toInt()}%',
        color: colors[i % colors.length],
        radius: 36,
        titleStyle: GoogleFonts.poppins(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600),
      ));
    }

    return PieChart(PieChartData(sections: sections, sectionsSpace: 4, centerSpaceRadius: 18));
  }

  Widget _buildCountriesLegend({double? maxWidth}) {
    final colors = [Colors.blue, Colors.orange, Colors.green, Colors.purple, Colors.amber];
    final entries = countries.entries.toList();
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(entries.length, (i) {
        final key = entries[i].key;
        final value = entries[i].value;
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(width: 12, height: 12, decoration: BoxDecoration(color: colors[i % colors.length], shape: BoxShape.circle)),
              const SizedBox(width: 8),
              // constrain the legend text so it wraps and doesn't push the row horizontally
              Expanded(
                child: Text(
                  '$key — ${value.toInt()}%',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.poppins(fontSize: 13),
                ),
              ),
            ],
          ),
        );
      }),
    );
  }

  // -------- Line chart ----------
  Widget _buildLineChart() {
    final spots = List.generate(distanceTrend.length, (i) => FlSpot(i.toDouble(), distanceTrend[i]));
    return LineChart(
      LineChartData(
        lineBarsData: [
          LineChartBarData(spots: spots, isCurved: true, color: const Color(0xFF4F9AFF), barWidth: 3, dotData: FlDotData(show: true)),
        ],
        titlesData: FlTitlesData(
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 28,
              getTitlesWidget: (value, meta) {
                const labels = ['Jan','Feb','Mar','Apr','May','Jun'];
                final idx = value.toInt();
                final text = (idx >= 0 && idx < labels.length) ? labels[idx] : '';
                return Text(text, style: GoogleFonts.poppins(fontSize: 11));
              },
            ),
          ),
          leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, reservedSize: 40, getTitlesWidget: (v, meta) {
            if (v <= 0.75) return Text('0k', style: GoogleFonts.poppins(fontSize: 10));
            if (v <= 1.5) return Text('0.75k', style: GoogleFonts.poppins(fontSize: 10));
            if (v <= 2.25) return Text('1.5k', style: GoogleFonts.poppins(fontSize: 10));
            if (v <= 3.0) return Text('2.25k', style: GoogleFonts.poppins(fontSize: 10));
            return Text('', style: GoogleFonts.poppins(fontSize: 10));
          })),
          rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
          topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
        ),
        gridData: FlGridData(show: true, drawVerticalLine: false, horizontalInterval: 0.75),
        borderData: FlBorderData(show: false),
        minY: 0,
        maxY: 3.0,
      ),
    );
  }
}
