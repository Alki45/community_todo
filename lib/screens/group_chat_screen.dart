import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
// Temporarily disabled - file/image attachments not supported
// import 'package:http/http.dart' as http;
// import 'dart:io';
// import 'package:path_provider/path_provider.dart';
// import 'package:open_filex/open_filex.dart';
// import 'package:image_picker/image_picker.dart';

import '../models/chat_message.dart';
import '../models/group_model.dart';
import '../models/user_model.dart';
import '../models/group_announcement.dart';
import '../providers/user_provider.dart';
import '../services/firestore_service.dart';
// Temporarily disabled - file/image attachments not supported
// import '../services/storage_service.dart';

class GroupChatScreen extends StatefulWidget {
  const GroupChatScreen({
    super.key,
    required this.group,
  });

  final Group group;

  @override
  State<GroupChatScreen> createState() => _GroupChatScreenState();
}

class _GroupChatScreenState extends State<GroupChatScreen> {
  final TextEditingController _messageController = TextEditingController();
  final FocusNode _messageFocusNode = FocusNode();
  final ScrollController _scrollController = ScrollController();
  // Temporarily disabled - file/image attachments not supported
  // final StorageService _storageService = StorageService();
  bool _isSending = false;
  bool _showEmojiPicker = false;
  // List<FileAttachment> _attachments = [];

  @override
  void dispose() {
    _messageController.dispose();
    _messageFocusNode.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  // Temporarily disabled - file/image attachments not supported
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
          _isSending = true;
        });

        try {
          final attachment = await _storageService.uploadImageFile(
            file: image,
            groupId: widget.group.id,
            userId: context.read<UserProvider>().user!.uid,
            subfolder: 'chat',
          );
          setState(() {
            _attachments.add(attachment);
            _isSending = false;
          });
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Image attached.')),
            );
          }
        } catch (e) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Failed to upload image: $e'),
                backgroundColor: Theme.of(context).colorScheme.error,
              ),
            );
            setState(() {
              _isSending = false;
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

  // Temporarily disabled - file/image attachments not supported
  /*
  Future<void> _pickFile() async {
    try {
      final result = await _storageService.pickFile();
      if (result != null && result.files.single.path != null) {
        setState(() {
          _isSending = true;
        });

        try {
          final attachment = await _storageService.uploadPlatformFile(
            platformFile: result.files.single,
            groupId: widget.group.id,
            userId: context.read<UserProvider>().user!.uid,
            subfolder: 'chat',
          );
          setState(() {
            _attachments.add(attachment);
            _isSending = false;
          });
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('File attached.')),
            );
          }
        } catch (e) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Failed to upload file: $e'),
                backgroundColor: Theme.of(context).colorScheme.error,
              ),
            );
            setState(() {
              _isSending = false;
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

  // Temporarily disabled - file/image attachments not supported
  /*
  void _removeAttachment(FileAttachment attachment) {
    setState(() {
      _attachments.remove(attachment);
    });
  }
  */

  Future<void> _sendMessage() async {
    final message = _messageController.text.trim();
    // Temporarily disabled - file/image attachments not supported
    // if (message.isEmpty && _attachments.isEmpty) {
    if (message.isEmpty) {
      return;
    }

    final userProvider = context.read<UserProvider>();
    final user = userProvider.user;
    if (user == null) return;

    setState(() {
      _isSending = true;
    });

    final firestore = context.read<FirestoreService>();
    try {
      await firestore.sendChatMessage(
        group: widget.group,
        sender: user,
        message: message,
        // Temporarily disabled - file/image attachments not supported
        // attachments: _attachments.map((a) => a.toMap()).toList(),
        attachments: [],
      );
      _messageController.clear();
      setState(() {
        // _attachments.clear();
        _showEmojiPicker = false;
      });
      _scrollToBottom();
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to send message: $error'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSending = false;
        });
      }
    }
  }

  // Temporarily disabled - file/image attachments not supported
  /*
  Future<void> _downloadFile(FileAttachment attachment) async {
    try {
      final response = await http.get(Uri.parse(attachment.url));
      if (response.statusCode == 200) {
        final directory = await getApplicationDocumentsDirectory();
        final filePath = '${directory.path}/${attachment.fileName}';
        final file = File(filePath);
        await file.writeAsBytes(response.bodyBytes);
        
        if (mounted) {
          await OpenFilex.open(filePath);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('File saved: ${attachment.fileName}')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to download file: $e'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    }
  }
  */
  
  // Placeholder function to prevent errors
  Future<void> _downloadFile(FileAttachment attachment) async {
    // Temporarily disabled - file/image attachments not supported
  }

  @override
  Widget build(BuildContext context) {
    final userProvider = context.watch<UserProvider>();
    final user = userProvider.user;
    final firestore = context.read<FirestoreService>();
    final isSmallScreen = MediaQuery.of(context).size.height < 700;

    if (user == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Group Chat')),
        body: const Center(child: Text('Please sign in to chat')),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.group.name,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            Text(
              '${widget.group.memberCount} members',
              style: TextStyle(
                fontSize: 12,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: StreamBuilder<List<ChatMessage>>(
              stream: firestore.watchGroupMessages(widget.group.id),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (snapshot.hasError) {
                  return Center(
                    child: Text('Error: ${snapshot.error}'),
                  );
                }

                final messages = snapshot.data ?? [];
                if (messages.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.chat_bubble_outline,
                          size: 64,
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'No messages yet',
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                color: Theme.of(context).colorScheme.onSurfaceVariant,
                              ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Start the conversation!',
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                color: Theme.of(context).colorScheme.onSurfaceVariant,
                              ),
                        ),
                      ],
                    ),
                  );
                }

                WidgetsBinding.instance.addPostFrameCallback((_) {
                  _scrollToBottom();
                });

                return ListView.builder(
                  controller: _scrollController,
                  padding: EdgeInsets.all(isSmallScreen ? 12 : 16),
                  itemCount: messages.length,
                  itemBuilder: (context, index) {
                    final message = messages[index];
                    final isMe = message.senderUid == user.uid;
                    final showAvatar = index == 0 ||
                        messages[index - 1].senderUid != message.senderUid;

                    return _ChatMessageBubble(
                      message: message,
                      isMe: isMe,
                      showAvatar: showAvatar,
                      isSmallScreen: isSmallScreen,
                      onFileTap: _downloadFile,
                    );
                  },
                );
              },
            ),
          ),
          // Message input area
          Container(
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 4,
                  offset: const Offset(0, -2),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Temporarily disabled - file/image attachments not supported
                /*
                if (_attachments.isNotEmpty)
                  Container(
                    height: 60,
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    child: ListView(
                      scrollDirection: Axis.horizontal,
                      children: _attachments.map((attachment) {
                        return Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: Chip(
                            avatar: Icon(
                              attachment.isImage
                                  ? Icons.image
                                  : attachment.isPdf
                                      ? Icons.picture_as_pdf
                                      : Icons.description,
                              size: 16,
                            ),
                            label: Text(attachment.fileName),
                            onDeleted: () => _removeAttachment(attachment),
                            deleteIcon: const Icon(Icons.close, size: 18),
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                */
                Padding(
                  padding: EdgeInsets.all(isSmallScreen ? 8 : 12),
                  child: Row(
                    children: [
                      // Temporarily disabled - file/image attachments not supported
                      /*
                      IconButton(
                        icon: const Icon(Icons.image),
                        tooltip: 'Attach image',
                        onPressed: _isSending ? null : _pickImage,
                      ),
                      IconButton(
                        icon: const Icon(Icons.attach_file),
                        tooltip: 'Attach document',
                        onPressed: _isSending ? null : _pickFile,
                      ),
                      */
                      Expanded(
                        child: TextField(
                          controller: _messageController,
                          focusNode: _messageFocusNode,
                          maxLines: null,
                          minLines: 1,
                          textCapitalization: TextCapitalization.sentences,
                          decoration: InputDecoration(
                            hintText: 'Type a message...',
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(24),
                            ),
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 8,
                            ),
                          ),
                          onSubmitted: (_) => _sendMessage(),
                        ),
                      ),
                      const SizedBox(width: 8),
                      IconButton(
                        icon: _isSending
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Icon(Icons.send),
                        onPressed: _isSending ? null : _sendMessage,
                        tooltip: 'Send message',
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ChatMessageBubble extends StatelessWidget {
  const _ChatMessageBubble({
    required this.message,
    required this.isMe,
    required this.showAvatar,
    required this.isSmallScreen,
    required this.onFileTap,
  });

  final ChatMessage message;
  final bool isMe;
  final bool showAvatar;
  final bool isSmallScreen;
  final void Function(FileAttachment) onFileTap;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isToday = DateFormat('yyyy-MM-dd').format(message.createdAt) ==
        DateFormat('yyyy-MM-dd').format(DateTime.now());
    final timeFormat = isToday
        ? DateFormat('HH:mm')
        : DateFormat('MMM d, HH:mm');

    return Padding(
      padding: EdgeInsets.only(bottom: isSmallScreen ? 8 : 12),
      child: Row(
        mainAxisAlignment: isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!isMe && showAvatar) ...[
            CircleAvatar(
              radius: isSmallScreen ? 14 : 16,
              child: Text(
                message.senderName.isNotEmpty
                    ? message.senderName[0].toUpperCase()
                    : '?',
                style: TextStyle(fontSize: isSmallScreen ? 12 : 14),
              ),
            ),
            const SizedBox(width: 8),
          ] else if (!isMe) ...[
            SizedBox(width: isSmallScreen ? 30 : 40),
          ],
          Flexible(
            child: Container(
              padding: EdgeInsets.all(isSmallScreen ? 10 : 12),
              decoration: BoxDecoration(
                color: isMe
                    ? colorScheme.primaryContainer
                    : colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (!isMe)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Text(
                        message.senderName,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              fontWeight: FontWeight.w600,
                              fontSize: isSmallScreen ? 11 : null,
                              color: colorScheme.primary,
                            ),
                      ),
                    ),
                  if (message.message.isNotEmpty)
                    Text(
                      message.message,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            fontSize: isSmallScreen ? 13 : null,
                          ),
                    ),
                  // Temporarily disabled - file/image attachments not supported
                  /*
                  if (message.attachments.isNotEmpty) ...[
                    if (message.message.isNotEmpty) const SizedBox(height: 8),
                    ...message.attachments.map((attachment) {
                      return InkWell(
                        onTap: () => onFileTap(attachment),
                        child: Container(
                          margin: const EdgeInsets.only(bottom: 4),
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: colorScheme.surface,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                attachment.isImage
                                    ? Icons.image
                                    : attachment.isPdf
                                        ? Icons.picture_as_pdf
                                        : Icons.description,
                                size: 20,
                              ),
                              const SizedBox(width: 8),
                              Flexible(
                                child: Text(
                                  attachment.fileName,
                                  style: Theme.of(context).textTheme.bodySmall,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    }),
                  ],
                  */
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      timeFormat.format(message.createdAt),
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            fontSize: isSmallScreen ? 10 : null,
                            color: colorScheme.onSurfaceVariant,
                          ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (isMe && showAvatar) ...[
            const SizedBox(width: 8),
            CircleAvatar(
              radius: isSmallScreen ? 14 : 16,
              child: Text(
                message.senderName.isNotEmpty
                    ? message.senderName[0].toUpperCase()
                    : '?',
                style: TextStyle(fontSize: isSmallScreen ? 12 : 14),
              ),
            ),
          ] else if (isMe) ...[
            SizedBox(width: isSmallScreen ? 30 : 40),
          ],
        ],
      ),
    );
  }
}

