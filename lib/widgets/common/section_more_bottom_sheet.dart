import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:get/get.dart';
import '../../core/theme.dart';

class SectionMoreOption {
  final String title;
  final IconData icon;
  final VoidCallback onTap;

  SectionMoreOption({
    required this.title,
    required this.icon,
    required this.onTap,
  });
}

class SectionMoreBottomSheet extends StatelessWidget {
  final String sectionTitle;
  final List<SectionMoreOption> options;

  const SectionMoreBottomSheet({
    Key? key,
    required this.sectionTitle,
    required this.options,
  }) : super(key: key);

  static void show(BuildContext context, {required String sectionTitle, required List<SectionMoreOption> options}) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => SectionMoreBottomSheet(sectionTitle: sectionTitle, options: options),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 16,
        bottom: MediaQuery.of(context).padding.bottom + 16,
      ),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF13131F) : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.2), blurRadius: 16, offset: const Offset(0, -4)),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: isDark ? Colors.white24 : Colors.black26,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 14),
          Text(
            sectionTitle.toUpperCase(),
            style: GoogleFonts.outfit(
              color: context.caption,
              fontSize: 12,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(height: 12),
          ...options.map((opt) {
            return ListTile(
              leading: Icon(opt.icon, color: context.primaryColor, size: 20),
              title: Text(
                opt.title,
                style: GoogleFonts.poppins(color: context.textPrimary, fontSize: 13, fontWeight: FontWeight.w600),
              ),
              onTap: () {
                Navigator.pop(context);
                opt.onTap();
              },
            );
          }).toList(),
        ],
      ),
    );
  }
}
