import 'dart:math';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:creania/core/theme.dart';
import '../../services/study_vault_controller.dart';
import '../../services/user_profile_cache_manager.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:io';
import 'package:image_picker/image_picker.dart';
import '../../widgets/custom_image_editor.dart';

class UploadBookScreen extends StatefulWidget {
  const UploadBookScreen({Key? key}) : super(key: key);

  @override
  State<UploadBookScreen> createState() => _UploadBookScreenState();
}

class _UploadBookScreenState extends State<UploadBookScreen> {
  final StudyVaultController _controller = Get.find<StudyVaultController>();
  final _formKey = GlobalKey<FormState>();

  // Form Fields
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _subtitleController = TextEditingController();
  final TextEditingController _descController = TextEditingController();
  final TextEditingController _authorController = TextEditingController();
  final TextEditingController _publisherController = TextEditingController();
  final TextEditingController _editionController = TextEditingController(text: '1st Edition');
  final TextEditingController _isbnController = TextEditingController();
  final TextEditingController _pagesController = TextEditingController(text: '100');
  final TextEditingController _tagsController = TextEditingController();
  final TextEditingController _priceController = TextEditingController(text: '100');

  String _selectedCategory = 'Coding';
  String _selectedFileType = 'PDF';
  String _selectedPreviewOption = '5 Pages';
  int _customPreviewPages = 5;

  String _course = 'BTech';
  String _semester = '1st';
  String _branch = 'Computer Science';
  String _university = 'Mumbai University';
  String _language = 'English';

  String _selectedCoverUrl = 'https://images.unsplash.com/photo-1543002588-bfa74002ed7e?w=400';
  String _selectedPdfName = '';
  bool _copyrightDeclared = false;

  final List<String> _categories = [
    'Engineering', 'Medical', 'MBA', 'BCA', 'BTech', 'MTech', 'MCA', 'Diploma',
    'Commerce', 'Law', 'Arts', 'Science', 'School', 'UPSC', 'SSC', 'Bank', 'Railway',
    'State PSC', 'JEE', 'NEET', 'GATE', 'CAT', 'Coding', 'AI', 'Cyber Security',
    'Machine Learning', 'Programming', 'Networking', 'Cloud Computing', 'Research',
    'Projects', 'Assignments', 'Question Banks', 'Previous Year Papers',
    'Interview Preparation', 'Language Learning', 'Soft Skills', 'Career', 'Others'
  ];

  final List<String> _fileTypes = ['PDF', 'Notes', 'Books', 'Projects', 'Assignments', 'Question Banks', 'Previous Year Papers', 'Research Paper'];
  final List<String> _previewOptions = ['3 Pages', '5 Pages', '10 Pages', 'Custom'];

  // Cover image options for simulation
  final List<String> _mockCovers = [
    'https://images.unsplash.com/photo-1543002588-bfa74002ed7e?w=400',
    'https://images.unsplash.com/photo-1516979187457-637abb4f9353?w=400',
    'https://images.unsplash.com/photo-1506880018603-83d5b814b5a6?w=400',
    'https://images.unsplash.com/photo-1497633762265-9d179a990aa6?w=400',
    'https://images.unsplash.com/photo-1495446815901-a7297e63b58d?w=400',
  ];

  @override
  void dispose() {
    _titleController.dispose();
    _subtitleController.dispose();
    _descController.dispose();
    _authorController.dispose();
    _publisherController.dispose();
    _editionController.dispose();
    _isbnController.dispose();
    _pagesController.dispose();
    _tagsController.dispose();
    _priceController.dispose();
    super.dispose();
  }

  void _simulateFileSelection() {
    setState(() {
      _selectedPdfName = 'Ebook_Upload_${Random().nextInt(900) + 100}.pdf';
    });
    Get.snackbar(
      'File Selected 📁',
      'Loaded PDF successfully: $_selectedPdfName',
      backgroundColor: context.accentOrange.withOpacity(0.9),
      colorText: Colors.white,
      snackPosition: SnackPosition.BOTTOM,
    );
  }

  void _submitUpload() {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedPdfName.isEmpty) {
      Get.snackbar('Upload Error ⚠️', 'Please select a PDF document file to upload.');
      return;
    }
    if (!_copyrightDeclared) {
      Get.snackbar('Upload Error ⚠️', 'You must declare that you own the copyrights or have license to distribute this file.');
      return;
    }

    final double price = double.tryParse(_priceController.text) ?? 0.0;
    int previewPages = 5;
    if (_selectedPreviewOption == '3 Pages') previewPages = 3;
    else if (_selectedPreviewOption == '10 Pages') previewPages = 10;
    else previewPages = _customPreviewPages;

    final tagsList = _tagsController.text.split(',').map((t) => t.trim()).where((t) => t.isNotEmpty).toList();

    _controller.uploadBook(
      title: _titleController.text.trim(),
      subtitle: _subtitleController.text.trim(),
      description: _descController.text.trim(),
      category: _selectedCategory,
      course: _course,
      semester: _semester,
      branch: _branch,
      university: _university,
      language: _language,
      tags: tagsList.isEmpty ? [_selectedCategory] : tagsList,
      authorName: _authorController.text.trim().isEmpty ? (UserProfileCacheManager.currentUser?.username ?? Supabase.instance.client.auth.currentUser?.email?.split('@')[0] ?? 'Author') : _authorController.text.trim(),
      publisher: _publisherController.text.trim().isEmpty ? 'Self-Published' : _publisherController.text.trim(),
      edition: _editionController.text.trim(),
      isbn: _isbnController.text.trim().isEmpty ? null : _isbnController.text.trim(),
      pages: int.tryParse(_pagesController.text) ?? 100,
      fileType: _selectedFileType,
      basePrice: price,
      previewPages: previewPages,
      pdfName: _selectedPdfName,
      coverUrl: _selectedCoverUrl,
    );

    Get.back();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text(
          'Upload Study Resource',
          style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 18),
        ),
        backgroundColor: context.secondaryBackgroundColor,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_rounded, color: Colors.white),
          onPressed: () => Get.back(),
        ),
      ),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: EdgeInsets.all(20),
            physics: const BouncingScrollPhysics(),
            children: [
              // Cover Picker
              _buildCoverImagePicker(),
              SizedBox(height: 24),

              // File attachment picker
              _buildPdfFilePicker(),
              SizedBox(height: 24),

              // Basic details section
              _buildSectionTitle('Basic Details'),
              SizedBox(height: 12),
              _buildTextField(
                _titleController, 
                'Title', 
                'e.g., Fluid Mechanics Handwritten Notes', 
                textCapitalization: TextCapitalization.words,
                textInputAction: TextInputAction.next,
                validator: (v) => v!.isEmpty ? 'Title is required' : null,
              ),
              SizedBox(height: 12),
              _buildTextField(
                _subtitleController, 
                'Subtitle', 
                'e.g., Complete derivations & solved questions for semester exams',
                textCapitalization: TextCapitalization.words,
                textInputAction: TextInputAction.next,
              ),
              SizedBox(height: 12),
              _buildTextField(
                _descController, 
                'Description', 
                'Write a detailed description explaining what is included, who it is for, and how it will help students study.', 
                maxLines: 4, 
                textCapitalization: TextCapitalization.sentences,
                textInputAction: TextInputAction.newline,
                validator: (v) => v!.isEmpty ? 'Description is required' : null,
              ),
              
              SizedBox(height: 24),
              _buildSectionTitle('Categories & Categorization'),
              SizedBox(height: 12),
              Row(
                children: [
                  Expanded(child: _buildDropdownField('Category', _selectedCategory, _categories, (val) => setState(() => _selectedCategory = val!))),
                  SizedBox(width: 12),
                  Expanded(child: _buildDropdownField('Resource Type', _selectedFileType, _fileTypes, (val) => setState(() => _selectedFileType = val!))),
                ],
              ),
              SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Course', style: TextStyle(color: context.caption, fontSize: 11)),
                        SizedBox(height: 6),
                        TextFormField(
                          initialValue: _course,
                          onChanged: (v) => _course = v,
                          style: TextStyle(color: Colors.white, fontSize: 13),
                          decoration: const InputDecoration(contentPadding: EdgeInsets.symmetric(horizontal: 14, vertical: 12)),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Semester', style: TextStyle(color: context.caption, fontSize: 11)),
                        SizedBox(height: 6),
                        TextFormField(
                          initialValue: _semester,
                          onChanged: (v) => _semester = v,
                          style: TextStyle(color: Colors.white, fontSize: 13),
                          decoration: const InputDecoration(contentPadding: EdgeInsets.symmetric(horizontal: 14, vertical: 12)),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Branch / Subject', style: TextStyle(color: context.caption, fontSize: 11)),
                        SizedBox(height: 6),
                        TextFormField(
                          initialValue: _branch,
                          onChanged: (v) => _branch = v,
                          style: TextStyle(color: Colors.white, fontSize: 13),
                          decoration: const InputDecoration(contentPadding: EdgeInsets.symmetric(horizontal: 14, vertical: 12)),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('University / College', style: TextStyle(color: context.caption, fontSize: 11)),
                        SizedBox(height: 6),
                        TextFormField(
                          initialValue: _university,
                          onChanged: (v) => _university = v,
                          style: TextStyle(color: Colors.white, fontSize: 13),
                          decoration: const InputDecoration(contentPadding: EdgeInsets.symmetric(horizontal: 14, vertical: 12)),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Language', style: TextStyle(color: context.caption, fontSize: 11)),
                        SizedBox(height: 6),
                        TextFormField(
                          initialValue: _language,
                          onChanged: (v) => _language = v,
                          style: TextStyle(color: Colors.white, fontSize: 13),
                          decoration: const InputDecoration(contentPadding: EdgeInsets.symmetric(horizontal: 14, vertical: 12)),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(width: 12),
                  Expanded(
                    child: _buildTextField(
                      _tagsController, 
                      'Tags', 
                      'e.g., physics, formula, exam, hand-notes (comma separated)',
                      textCapitalization: TextCapitalization.none,
                      textInputAction: TextInputAction.next,
                    ),
                  ),
                ],
              ),

              SizedBox(height: 24),
              _buildSectionTitle('Publisher Info'),
              SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _buildTextField(
                      _authorController, 
                      'Author Name', 
                      'e.g., Dr. Amit Sen (or self)',
                      textCapitalization: TextCapitalization.words,
                      textInputAction: TextInputAction.next,
                    ),
                  ),
                  SizedBox(width: 12),
                  Expanded(
                    child: _buildTextField(
                      _publisherController, 
                      'Publisher', 
                      'e.g., Wiley or Self-Written',
                      textCapitalization: TextCapitalization.words,
                      textInputAction: TextInputAction.next,
                    ),
                  ),
                ],
              ),
              SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _buildTextField(
                      _editionController, 
                      'Edition', 
                      'e.g., 2026 Edition',
                      textCapitalization: TextCapitalization.words,
                      textInputAction: TextInputAction.next,
                    ),
                  ),
                  SizedBox(width: 12),
                  Expanded(
                    child: _buildTextField(
                      _isbnController, 
                      'ISBN (optional)', 
                      'e.g., 978-X-...',
                      textCapitalization: TextCapitalization.none,
                      textInputAction: TextInputAction.next,
                    ),
                  ),
                ],
              ),
              SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _buildTextField(
                      _pagesController, 
                      'Total Pages', 
                      'e.g., 148', 
                      keyboardType: TextInputType.number, 
                      textCapitalization: TextCapitalization.none,
                      textInputAction: TextInputAction.done,
                      validator: (v) => int.tryParse(v ?? '') == null ? 'Enter page count' : null,
                    ),
                  ),
                  SizedBox(width: 12),
                  Expanded(child: _buildDropdownField('Preview Pages count', _selectedPreviewOption, _previewOptions, (val) {
                    setState(() {
                      _selectedPreviewOption = val!;
                      if (_selectedPreviewOption != 'Custom') {
                        _customPreviewPages = int.parse(_selectedPreviewOption.split(' ')[0]);
                      }
                    });
                  })),
                ],
              ),

              if (_selectedPreviewOption == 'Custom') ...[
                SizedBox(height: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Custom Preview Pages (Must contain Watermark)', style: TextStyle(color: context.caption, fontSize: 11)),
                    SizedBox(height: 6),
                    Row(
                      children: [
                        Expanded(
                          child: Slider(
                            value: _customPreviewPages.toDouble(),
                            min: 1,
                            max: 50,
                            divisions: 49,
                            activeColor: context.primaryColor,
                            inactiveColor: context.borderColor,
                            onChanged: (val) {
                              setState(() {
                                _customPreviewPages = val.toInt();
                              });
                            },
                          ),
                        ),
                        Container(
                          width: 60,
                          alignment: Alignment.center,
                          padding: EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                          decoration: BoxDecoration(
                            color: context.surfaceColor,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: context.borderColor),
                          ),
                          child: Text(
                            '$_customPreviewPages pgs',
                            style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ],

              SizedBox(height: 24),
              _buildSectionTitle('Pricing System (₹)'),
              SizedBox(height: 12),
              _buildTextField(
                _priceController, 
                'Your Base Selling Price (₹)', 
                'e.g. 100 (Type 0 for Free)', 
                keyboardType: TextInputType.number, 
                onChanged: (v) => setState(() {}),
                validator: (v) {
                  final val = double.tryParse(v ?? '');
                  if (val == null) return 'Enter a valid base price';
                  if (val < 0) return 'Price cannot be negative';
                  return null;
                }
              ),
              SizedBox(height: 12),
              _buildLivePriceBreakdownCard(),

              SizedBox(height: 24),
              // Copyright declaration check
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Checkbox(
                    value: _copyrightDeclared,
                    activeColor: context.primaryColor,
                    onChanged: (val) => setState(() => _copyrightDeclared = val ?? false),
                  ),
                  Expanded(
                    child: Padding(
                      padding: EdgeInsets.only(top: 8.0),
                      child: Text(
                        'I declare that this file is my own original work (or I hold copyright distribution rights). I understand copyright infringement is illegal and Creaniaa will suspend my seller account in case of piracy reports.',
                        style: GoogleFonts.poppins(color: context.textSecondary, fontSize: 11, height: 1.4),
                      ),
                    ),
                  ),
                ],
              ),

              SizedBox(height: 24),
              // Submit button
              SizedBox(
                height: 52,
                child: ElevatedButton(
                  onPressed: _submitUpload,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: context.primaryColor,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                  child: Text(
                    'Submit for Approval',
                    style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                ),
              ),
              SizedBox(height: 30),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title.toUpperCase(),
      style: GoogleFonts.outfit(
        color: context.primaryColor,
        fontSize: 12,
        fontWeight: FontWeight.bold,
        letterSpacing: 1.2,
      ),
    );
  }

  Widget _buildCoverImagePicker() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Select Cover Design', style: TextStyle(color: context.caption, fontSize: 11)),
        SizedBox(height: 8),
        SizedBox(
          height: 130,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            itemCount: _mockCovers.length + 1,
            itemBuilder: (context, i) {
              if (i == _mockCovers.length) {
                // custom add cover card
                return GestureDetector(
                  onTap: () async {
                    final picker = ImagePicker();
                    final XFile? image = await picker.pickImage(source: ImageSource.gallery);
                    if (image != null) {
                      final editedFile = await CustomImageEditor.editImage(context, File(image.path));
                      if (editedFile != null) {
                        setState(() {
                          _selectedCoverUrl = editedFile.path;
                          if (!_mockCovers.contains(editedFile.path)) {
                            _mockCovers.add(editedFile.path);
                          }
                        });
                      }
                    }
                  },
                  child: Container(
                    width: 90,
                    margin: EdgeInsets.only(right: 12),
                    decoration: BoxDecoration(
                      color: context.surfaceColor,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: context.borderColor, style: BorderStyle.values[1]),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.add_photo_alternate_outlined, color: context.caption),
                        SizedBox(height: 4),
                        Text('Custom', style: TextStyle(color: context.caption, fontSize: 10)),
                      ],
                    ),
                  ),
                );
              }

              final cover = _mockCovers[i];
              final isSelected = cover == _selectedCoverUrl;
              return GestureDetector(
                onTap: () => setState(() => _selectedCoverUrl = cover),
                child: Container(
                  width: 90,
                  margin: EdgeInsets.only(right: 12),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isSelected ? context.primaryColor : Colors.transparent,
                      width: 3,
                    ),
                    image: DecorationImage(
                      image: cover.startsWith('http')
                          ? NetworkImage(cover)
                          : FileImage(File(cover)) as ImageProvider,
                      fit: BoxFit.cover,
                    ),
                  ),
                  child: isSelected
                      ? Align(
                          alignment: Alignment.topRight,
                          child: Padding(
                            padding: EdgeInsets.all(4.0),
                            child: Icon(Icons.check_circle, color: context.primaryColor, size: 18),
                          ),
                        )
                      : null,
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildPdfFilePicker() {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: context.surfaceColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: _selectedPdfName.isNotEmpty ? context.accentOrange.withOpacity(0.5) : context.borderColor,
        ),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                padding: EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: (_selectedPdfName.isNotEmpty ? context.accentOrange : context.primaryColor).withOpacity(0.12),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  _selectedPdfName.isNotEmpty ? Icons.picture_as_pdf : Icons.cloud_upload_outlined,
                  color: _selectedPdfName.isNotEmpty ? context.accentOrange : context.primaryColor,
                  size: 24,
                ),
              ),
              SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _selectedPdfName.isNotEmpty ? 'Document Selected' : 'Select PDF File',
                      style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold),
                    ),
                    SizedBox(height: 4),
                    Text(
                      _selectedPdfName.isNotEmpty ? _selectedPdfName : 'Only PDF format is supported. Max 50MB.',
                      style: TextStyle(color: context.caption, fontSize: 11),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              OutlinedButton(
                onPressed: _simulateFileSelection,
                style: OutlinedButton.styleFrom(
                  padding: EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  side: BorderSide(
                    color: _selectedPdfName.isNotEmpty ? context.accentOrange : context.primaryColor,
                  ),
                ),
                child: Text(
                  _selectedPdfName.isNotEmpty ? 'Re-select' : 'Browse',
                  style: TextStyle(
                    color: _selectedPdfName.isNotEmpty ? context.accentOrange : context.primaryColor,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              )
            ],
          )
        ],
      ),
    );
  }

  Widget _buildTextField(
    TextEditingController controller, 
    String label, 
    String hint, {
    TextInputType keyboardType = TextInputType.text,
    int maxLines = 1,
    void Function(String)? onChanged,
    String? Function(String?)? validator,
    TextCapitalization textCapitalization = TextCapitalization.none,
    TextInputAction textInputAction = TextInputAction.next,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: TextStyle(color: context.caption, fontSize: 11)),
        SizedBox(height: 6),
        TextFormField(
          controller: controller,
          keyboardType: keyboardType,
          maxLines: maxLines,
          textCapitalization: textCapitalization,
          textInputAction: textInputAction,
          autocorrect: keyboardType == TextInputType.text,
          enableSuggestions: keyboardType == TextInputType.text,
          style: TextStyle(color: Colors.white, fontSize: 13),
          onChanged: onChanged,
          validator: validator,
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: TextStyle(color: context.caption, fontSize: 12),
            contentPadding: EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          ),
        ),
      ],
    );
  }

  Widget _buildDropdownField(String label, String value, List<String> items, void Function(String?) onChanged) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: TextStyle(color: context.caption, fontSize: 11)),
        SizedBox(height: 6),
        Container(
          padding: EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: context.surfaceColor,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: context.borderColor),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: value,
              dropdownColor: context.secondaryBackgroundColor,
              isExpanded: true,
              style: TextStyle(color: Colors.white, fontSize: 13),
              items: items.map((t) {
                return DropdownMenuItem<String>(
                  value: t,
                  child: Text(t, overflow: TextOverflow.ellipsis),
                );
              }).toList(),
              onChanged: onChanged,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildLivePriceBreakdownCard() {
    final double basePrice = double.tryParse(_priceController.text) ?? 0.0;
    
    if (basePrice <= 0) {
      return Container(
        padding: EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: context.accentOrange.withOpacity(0.06),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: context.accentOrange.withOpacity(0.2)),
        ),
        child: Row(
          children: [
            Icon(Icons.info_outline, color: context.accentOrange, size: 16),
            SizedBox(width: 8),
            Expanded(
              child: Text(
                'This resource is set as FREE. Any student can download and read it without paid tokens.',
                style: GoogleFonts.poppins(color: context.accentOrange, fontSize: 11, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
      );
    }

    final breakdown = _controller.calculatePriceBreakdown(basePrice);

    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: context.surfaceColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: context.borderColor.withOpacity(0.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.calculate_outlined, color: context.primaryColor, size: 18),
              SizedBox(width: 8),
              Text(
                'Interactive Price Breakdown',
                style: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
              ),
            ],
          ),
          SizedBox(height: 12),
          _priceRow('Seller Set Base Price', '₹${basePrice.toStringAsFixed(2)}', isHeader: true),
          Divider(color: Colors.white10),
          _priceRow('GST (18%)', '+ ₹${breakdown['gst']!.toStringAsFixed(2)}'),
          _priceRow('Payment Gateway (2%)', '+ ₹${breakdown['paymentGateway']!.toStringAsFixed(2)}'),
          _priceRow('Platform Fee (17%)', '+ ₹${breakdown['platformFee']!.toStringAsFixed(2)}'),
          Divider(color: Colors.white10),
          _priceRow('Buyer Pays (Total Price)', '₹${breakdown['buyerPays']!.toStringAsFixed(2)}', highlightColor: context.accentOrange),
          _priceRow('You Receive (Your Earning)', '₹${breakdown['sellerReceives']!.toStringAsFixed(2)}', highlightColor: Color(0xFFFFD700)),
          _priceRow('Platform Receives (Taxes + Fees)', '₹${breakdown['platformReceives']!.toStringAsFixed(2)}'),
        ],
      ),
    );
  }

  Widget _priceRow(String label, String value, {bool isHeader = false, Color? highlightColor}) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: GoogleFonts.poppins(
              color: isHeader ? Colors.white : context.caption,
              fontSize: isHeader ? 12 : 11,
              fontWeight: isHeader ? FontWeight.bold : FontWeight.normal,
            ),
          ),
          Text(
            value,
            style: GoogleFonts.poppins(
              color: highlightColor ?? (isHeader ? Colors.white : context.textSecondary),
              fontSize: isHeader ? 12 : 11,
              fontWeight: (isHeader || highlightColor != null) ? FontWeight.bold : FontWeight.normal,
            ),
          ),
        ],
      ),
    );
  }
}
