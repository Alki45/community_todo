import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:image_picker/image_picker.dart';
import 'package:emoji_picker_flutter/emoji_picker_flutter.dart';
import 'package:provider/provider.dart';
import '../models/group_announcement.dart';
import '../models/group_model.dart';
import '../models/user_model.dart';
import '../services/storage_service.dart';
import '../services/firestore_service.dart';

class EnhancedAnnouncementComposer extends StatefulWidget {
  const EnhancedAnnouncementComposer({
    super.key,
    required this.group,
    required this.author,
    required this.onPosted,
  });

  final Group group;
  final AppUser author;
  final VoidCallback onPosted;

  @override
  State<EnhancedAnnouncementComposer> createState() =>
      _EnhancedAnnouncementComposerState();
}

class _EnhancedAnnouncementComposerState
    extends State<EnhancedAnnouncementComposer> {
  final TextEditingController _controller = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  // TODO: File sharing temporarily disabled - Firebase/Firestore not supporting file storage for now
  // final StorageService _storageService = StorageService();
  bool _isPosting = false;
  bool _isHadith = false;
  bool _showEmojiPicker = false;
  // List<FileAttachment> _attachments = [];

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  // TODO: File sharing temporarily disabled - Firebase/Firestore not supporting file storage for now
  // Enable this when Firebase Storage is properly configured
  /*
  Future<void> _pickImage() async {
    try {
      final source = await showDialog<ImageSource>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Select Image Source'),
          actions: [
            TextButton.icon(
              onPressed: () => Navigator.pop(context, ImageSource.gallery),
              icon: const Icon(Icons.photo_library),
              label: const Text('Gallery'),
            ),
            TextButton.icon(
              onPressed: () => Navigator.pop(context, ImageSource.camera),
              icon: const Icon(Icons.camera_alt),
              label: const Text('Camera'),
            ),
          ],
        ),
      );

      if (source == null) return;

      final image = await _storageService.pickImage(
        fromCamera: source == ImageSource.camera,
      );

      if (image != null && mounted) {
        setState(() {
          _isPosting = true;
        });

        try {
          final attachment = await _storageService.uploadImageFile(
            file: image,
            groupId: widget.group.id,
            userId: widget.author.uid,
          );
          setState(() {
            _attachments.add(attachment);
            _isPosting = false;
          });
        } catch (e) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Failed to upload image: $e'),
                backgroundColor: Theme.of(context).colorScheme.error,
              ),
            );
            setState(() {
              _isPosting = false;
            });
          }
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to pick image: $e'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    }
  }
  */

  // TODO: File sharing temporarily disabled - Firebase/Firestore not supporting file storage for now
  // Enable this when Firebase Storage is properly configured
  /*
  Future<void> _pickFile() async {
    try {
      final result = await _storageService.pickFile();
      if (result != null && result.files.single.path != null) {
        setState(() {
          _isPosting = true;
        });

        try {
          final attachment = await _storageService.uploadPlatformFile(
            platformFile: result.files.single,
            groupId: widget.group.id,
            userId: widget.author.uid,
          );
          setState(() {
            _attachments.add(attachment);
            _isPosting = false;
          });
        } catch (e) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Failed to upload file: $e'),
                backgroundColor: Theme.of(context).colorScheme.error,
              ),
            );
            setState(() {
              _isPosting = false;
            });
          }
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to pick file: $e'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    }
  }
  */

  // TODO: File sharing temporarily disabled - Firebase/Firestore not supporting file storage for now
  // Enable this when Firebase Storage is properly configured
  /*
  void _removeAttachment(int index) {
    setState(() {
      _attachments.removeAt(index);
    });
  }
  */

  Future<void> _postAnnouncement() async {
    final message = _controller.text.trim();
    // TODO: File sharing temporarily disabled - Firebase/Firestore not supporting file storage for now
    // if (message.isEmpty && _attachments.isEmpty) {
    if (message.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a message')),
      );
      return;
    }

    setState(() {
      _isPosting = true;
    });

    try {
      final firestore = context.read<FirestoreService>();
      await firestore.postAnnouncement(
        group: widget.group,
        author: widget.author,
        message: message,
        isHadith: _isHadith,
        // TODO: File sharing temporarily disabled - Firebase/Firestore not supporting file storage for now
        // attachments: _attachments.map((a) => a.toMap()).toList(),
        attachments: [],
      );

      _controller.clear();
      setState(() {
        _isHadith = false;
        // TODO: File sharing temporarily disabled
        // _attachments.clear();
        _showEmojiPicker = false;
      });

      widget.onPosted();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Announcement shared with the group.')),
        );
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Unable to share announcement: $error'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isPosting = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isSmallScreen = MediaQuery.of(context).size.height < 700;
    return Column(
      children: [
        Card(
          elevation: 0,
          child: Padding(
            padding: EdgeInsets.all(isSmallScreen ? 16 : 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Share a reminder',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontSize: isSmallScreen ? 16 : null,
                      ),
                ),
                SizedBox(height: isSmallScreen ? 8 : 12),
                TextField(
                  controller: _controller,
                  focusNode: _focusNode,
                  maxLines: isSmallScreen ? 3 : 4,
                  minLines: isSmallScreen ? 2 : 2,
                  textCapitalization: TextCapitalization.sentences,
                  style: TextStyle(fontSize: isSmallScreen ? 14 : null),
                  decoration: InputDecoration(
                    labelText: 'Announcement, reflection, or hadith',
                    alignLabelWithHint: true,
                    labelStyle: TextStyle(fontSize: isSmallScreen ? 13 : null),
                  ),
                ),
                // TODO: File sharing temporarily disabled - Firebase/Firestore not supporting file storage for now
                // Enable this when Firebase Storage is properly configured
                /*
                if (_attachments.isNotEmpty) ...[
                  SizedBox(height: isSmallScreen ? 8 : 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: _attachments.asMap().entries.map((entry) {
                      final index = entry.key;
                      final attachment = entry.value;
                      return Chip(
                        avatar: Icon(
                          attachment.isImage
                              ? Icons.image
                              : attachment.isPdf
                                  ? Icons.picture_as_pdf
                                  : Icons.description,
                        ),
                        label: Text(
                          attachment.fileName,
                          overflow: TextOverflow.ellipsis,
                          maxLines: 1,
                        ),
                        deleteIcon: const Icon(Icons.close, size: 18),
                        onDeleted: () => _removeAttachment(index),
                      );
                    }).toList(),
                  ),
                ],
                */
                SizedBox(height: isSmallScreen ? 8 : 12),
                Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.emoji_emotions_outlined),
                      onPressed: () {
                        setState(() {
                          _showEmojiPicker = !_showEmojiPicker;
                        });
                        if (_showEmojiPicker) {
                          _focusNode.unfocus();
                        }
                      },
                      tooltip: 'Add emoji',
                    ),
                    // TODO: File sharing temporarily disabled - Firebase/Firestore not supporting file storage for now
                    // Enable this when Firebase Storage is properly configured
                    /*
                    IconButton(
                      icon: const Icon(Icons.image_outlined),
                      onPressed: _isPosting ? null : _pickImage,
                      tooltip: 'Add image',
                    ),
                    IconButton(
                      icon: const Icon(Icons.attach_file),
                      onPressed: _isPosting ? null : _pickFile,
                      tooltip: 'Attach file (PDF, Word)',
                    ),
                    */
                    const Spacer(),
                    SwitchListTile.adaptive(
                      value: _isHadith,
                      onChanged: (value) {
                        setState(() {
                          _isHadith = value;
                        });
                      },
                      title: const Text('Hadith / Reflection'),
                      contentPadding: EdgeInsets.zero,
                      dense: true,
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                FilledButton.icon(
                  // TODO: File sharing temporarily disabled - Firebase/Firestore not supporting file storage for now
                  // onPressed: (_isPosting || (_controller.text.trim().isEmpty && _attachments.isEmpty))
                  onPressed: (_isPosting || _controller.text.trim().isEmpty)
                      ? null
                      : _postAnnouncement,
                  icon: _isPosting
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.send),
                  label: const Text('Share with group'),
                ),
              ],
            ),
          ),
        ),
        if (_showEmojiPicker)
          SizedBox(
            height: 250,
            child: EmojiPicker(
              onEmojiSelected: (category, emoji) {
                _controller.text = _controller.text + emoji.emoji;
              },
              config: const Config(
                height: 256,
                checkPlatformCompatibility: true,
              ),
            ),
          ),
      ],
    );
  }
}

