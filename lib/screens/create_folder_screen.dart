import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:twain/constants/app_colours.dart';
import 'package:twain/models/wallpaper_folder.dart';
import 'package:twain/providers/folder_providers.dart';
import 'package:twain/screens/folder_detail_screen.dart';

class CreateFolderScreen extends ConsumerStatefulWidget {
  final WallpaperFolder? folder; // For editing existing folder

  const CreateFolderScreen({super.key, this.folder});

  @override
  ConsumerState<CreateFolderScreen> createState() => _CreateFolderScreenState();
}

class _CreateFolderScreenState extends ConsumerState<CreateFolderScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _intervalController = TextEditingController();

  String _selectedUnit = 'hours';
  String _selectedOrder = 'sequential';
  bool _isSubmitting = false;

  bool get isEditing => widget.folder != null;

  @override
  void initState() {
    super.initState();
    if (isEditing) {
      _nameController.text = widget.folder!.name;
      _intervalController.text = widget.folder!.rotationIntervalValue.toString();
      _selectedUnit = widget.folder!.rotationIntervalUnit;
      _selectedOrder = widget.folder!.rotationOrder;
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _intervalController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(
        title: Text(
          isEditing ? 'Edit Folder' : 'Create Folder',
          style: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: AppColors.black,
          ),
        ),
        backgroundColor: Colors.white,
        elevation: 1,
        leading: IconButton(
          icon: const Icon(Icons.close, color: AppColors.black),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Folder Name
            _buildSectionTitle('Folder Name'),
            const SizedBox(height: 8),
            TextFormField(
              controller: _nameController,
              decoration: InputDecoration(
                hintText: 'Enter folder name',
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 14,
                ),
              ),
              textCapitalization: TextCapitalization.words,
              maxLength: 50,
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Please enter a folder name';
                }
                return null;
              },
            ),

            const SizedBox(height: 24),

            // Rotation Interval
            _buildSectionTitle('Rotation Interval'),
            const SizedBox(height: 8),
            Row(
              children: [
                // Number input
                Expanded(
                  flex: 2,
                  child: TextFormField(
                    controller: _intervalController,
                    decoration: InputDecoration(
                      hintText: 'Number',
                      filled: true,
                      fillColor: Colors.white,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 14,
                      ),
                    ),
                    keyboardType: TextInputType.number,
                    inputFormatters: [
                      FilteringTextInputFormatter.digitsOnly,
                    ],
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Required';
                      }
                      final num = int.tryParse(value);
                      if (num == null || num <= 0) {
                        return 'Must be > 0';
                      }
                      // Validate minimum interval (5 minutes)
                      if (_selectedUnit == 'minutes' && num < 5) {
                        return 'Min 5 min';
                      }
                      return null;
                    },
                  ),
                ),
                const SizedBox(width: 12),
                // Unit dropdown
                Expanded(
                  flex: 3,
                  child: DropdownButtonFormField<String>(
                    value: _selectedUnit,
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: Colors.white,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 14,
                      ),
                    ),
                    items: const [
                      DropdownMenuItem(value: 'minutes', child: Text('Minutes')),
                      DropdownMenuItem(value: 'hours', child: Text('Hours')),
                      DropdownMenuItem(value: 'days', child: Text('Days')),
                    ],
                    onChanged: (value) {
                      setState(() {
                        _selectedUnit = value!;
                        // Re-validate interval when unit changes
                        _formKey.currentState?.validate();
                      });
                    },
                  ),
                ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.only(top: 8, left: 4),
              child: Text(
                'Minimum interval: 5 minutes',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey[600],
                ),
              ),
            ),

            const SizedBox(height: 24),

            // Rotation Order
            _buildSectionTitle('Rotation Order'),
            const SizedBox(height: 8),
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                children: [
                  RadioListTile<String>(
                    title: const Text(
                      'Sequential',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    subtitle: const Text(
                      'Rotate images in order (1, 2, 3...)',
                      style: TextStyle(fontSize: 13),
                    ),
                    value: 'sequential',
                    groupValue: _selectedOrder,
                    activeColor: const Color(0xFFE91E63),
                    onChanged: (value) {
                      setState(() {
                        _selectedOrder = value!;
                      });
                    },
                  ),
                  Divider(height: 1, color: Colors.grey[300]),
                  RadioListTile<String>(
                    title: const Text(
                      'Random',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    subtitle: const Text(
                      'Rotate images in random order',
                      style: TextStyle(fontSize: 13),
                    ),
                    value: 'random',
                    groupValue: _selectedOrder,
                    activeColor: const Color(0xFFE91E63),
                    onChanged: (value) {
                      setState(() {
                        _selectedOrder = value!;
                      });
                    },
                  ),
                ],
              ),
            ),

            const SizedBox(height: 32),

            // Submit Button
            ElevatedButton(
              onPressed: _isSubmitting ? null : _handleSubmit,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFE91E63),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                disabledBackgroundColor: Colors.grey[300],
              ),
              child: _isSubmitting
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2,
                      ),
                    )
                  : Text(
                      isEditing ? 'Save Changes' : 'Create Folder',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: const TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.w600,
        color: AppColors.black,
      ),
    );
  }

  Future<void> _handleSubmit() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isSubmitting = true;
    });

    try {
      final service = ref.read(folderServiceProvider);
      final name = _nameController.text.trim();
      final intervalValue = int.parse(_intervalController.text);

      if (isEditing) {
        // Update existing folder
        await service.updateFolder(
          folderId: widget.folder!.id,
          name: name,
          rotationIntervalValue: intervalValue,
          rotationIntervalUnit: _selectedUnit,
          rotationOrder: _selectedOrder,
        );

        if (!mounted) return;
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Folder updated successfully'),
            backgroundColor: Colors.green,
          ),
        );
      } else {
        // Create new folder
        final folder = await service.createFolder(
          name: name,
          rotationIntervalValue: intervalValue,
          rotationIntervalUnit: _selectedUnit,
          rotationOrder: _selectedOrder,
        );

        if (!mounted) return;
        // Navigate to folder detail screen
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => FolderDetailScreen(folderId: folder.id),
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _isSubmitting = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to ${isEditing ? 'update' : 'create'} folder: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
}
