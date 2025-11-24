import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../models/app_announcement.dart';
import '../../models/group_announcement.dart';
import '../../models/group_model.dart';
import '../../models/recitation_model.dart';
import '../../providers/quran_provider.dart';
import '../../providers/user_provider.dart';
import '../../services/firestore_service.dart';
import '../../services/notification_service.dart';
import '../../widgets/todo_item.dart';
import '../../widgets/celebration_widget.dart';
import '../../widgets/refresh_button.dart';
import '../../services/storage_service.dart';
import '../../models/group_announcement.dart';
import 'package:open_filex/open_filex.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';
import 'package:http/http.dart' as http;
import '../../services/weekly_assignment_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../quran_reader_screen.dart';

class HomeTab extends StatefulWidget {
  const HomeTab({super.key});

  @override
  State<HomeTab> createState() => _HomeTabState();
}

class _HomeTabState extends State<HomeTab> {
  String? _selectedGroupId;
  final TextEditingController _announcementController = TextEditingController();
  final FocusNode _announcementFocusNode = FocusNode();
  bool _isPosting = false;
  bool _isHadith = false;

  static const List<_QuranHighlight> _quranHighlights = [
    _QuranHighlight(
      surah: 'Al-Fatihah',
      ayahRange: '1-7',
      caption: 'Opening supplication',
    ),
    _QuranHighlight(
      surah: 'Al-Baqarah',
      ayahRange: '285-286',
      caption: 'Closing verses of Al-Baqarah',
    ),
    _QuranHighlight(
      surah: 'Ash-Sharh',
      ayahRange: '1-8',
      caption: 'Relief after difficulty',
    ),
    _QuranHighlight(
      surah: 'Al-Kahf',
      ayahRange: '9-16',
      caption: 'People of the Cave',
    ),
    _QuranHighlight(
      surah: 'Al-Ikhlas',
      ayahRange: '1-4',
      caption: 'Sincerity in faith',
    ),
  ];

  _QuranHighlight _highlightFor(DateTime date) {
    final index = _indexForDate(date, _quranHighlights.length);
    return _quranHighlights[index];
  }

  int _indexForDate(DateTime date, int length) {
    final startOfYear = DateTime(date.year);
    final dayIndex = date.difference(startOfYear).inDays;
    if (length <= 0) {
      return 0;
    }
    return dayIndex % length;
  }

  @override
  void dispose() {
    _announcementController.dispose();
    _announcementFocusNode.dispose();
    super.dispose();
  }

  void _syncSelectedGroup(List<Group> groups, UserProvider userProvider) {
    final user = userProvider.user;
    if (user == null) {
      return;
    }

    String? desired;
    if (groups.isEmpty) {
      desired = null;
    } else if (_selectedGroupId != null &&
        groups.any((group) => group.id == _selectedGroupId)) {
      desired = _selectedGroupId;
    } else if (user.activeGroupId != null &&
        groups.any((group) => group.id == user.activeGroupId)) {
      desired = user.activeGroupId;
    } else {
      desired = groups.first.id;
    }

    if (_selectedGroupId != desired) {
      setState(() {
        _selectedGroupId = desired;
      });
    }

    if (desired != null && user.activeGroupId != desired) {
      userProvider.setActiveGroup(desired);
    }
  }

  Future<void> _postAnnouncement({
    required Group group,
    required UserProvider userProvider,
  }) async {
    final message = _announcementController.text.trim();
    final author = userProvider.user;

    if (message.isEmpty || author == null) {
      return;
    }

    setState(() {
      _isPosting = true;
    });

    final firestore = context.read<FirestoreService>();
    try {
      await firestore.postAnnouncement(
        group: group,
        author: author,
        message: message,
        isHadith: _isHadith,
      );
      _announcementController.clear();
      setState(() {
        _isHadith = false;
      });
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

  void _showQuranSheet(
    BuildContext context,
    QuranProvider provider, {
    _QuranHighlight? highlight,
  }) {
    if (!provider.isLoaded) {
      final message = provider.isLoading
          ? 'Loading Qur\'an verses…'
          : 'Qur\'an dataset unavailable.';
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message)));
      return;
    }

    final target = highlight ?? _quranHighlights.first;
    final rangeParts = target.ayahRange.split('-');
    final startAyah = int.tryParse(rangeParts.first.trim());

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => QuranReaderScreen(
          initialSurah: target.surah,
          initialAyah: startAyah,
        ),
        fullscreenDialog: true,
      ),
    );
  }

  void _shareQuranHighlight(_QuranHighlight highlight, String verseText) {
    final trimmed = verseText.trim();
    if (trimmed.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Qur\'an verses are still loading.')),
      );
      return;
    }
    setState(() {
      _isHadith = true;
      _announcementController.text =
          '${highlight.surah} (${highlight.ayahRange})\n$trimmed';
    });
    FocusScope.of(context).requestFocus(_announcementFocusNode);
  }

  void _shareHadithStory(_HadithStory story) {
    setState(() {
      _isHadith = true;
      _announcementController.text = '"${story.quote}"\n— ${story.narratedBy}';
    });
    FocusScope.of(context).requestFocus(_announcementFocusNode);
  }


  void _showStoryIdeas(BuildContext context) {
    final ideas = [
      'Share a reflection from today\'s recitation.',
      'Highlight a member\'s progress to motivate the group.',
      'Invite everyone to a virtual halaqah this weekend.',
    ];

    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (context) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Story ideas', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 12),
            ...ideas.map(
              (idea) => ListTile(
                leading: const Icon(Icons.lightbulb_outline),
                title: Text(idea),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final userProvider = context.watch<UserProvider>();
    final quranProvider = context.watch<QuranProvider>();
    final user = userProvider.user;
    final colorScheme = Theme.of(context).colorScheme;

    if (userProvider.isLoading) {
      return Scaffold(
        backgroundColor: colorScheme.surface,
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (user == null) {
      return Scaffold(
        backgroundColor: colorScheme.surface,
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    final firestore = context.read<FirestoreService>();
    final now = DateTime.now();
    final highlight = _highlightFor(now);
    final highlightText = quranProvider.isLoaded
        ? quranProvider.verseText(
            highlight.surah,
            highlight.ayahRange,
            maxAyat: 8,
          )
        : '';
    final hadithStory = _HadithLibrary.storyForDate(now);

    return StreamBuilder<List<Group>>(
      stream: firestore.watchUserGroups(user.uid),
      builder: (context, snapshot) {
        final groups = snapshot.data ?? [];

        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) {
            return;
          }
          _syncSelectedGroup(groups, userProvider);
        });

        final baseSections = [
          _QuranHighlightCard(
            highlight: highlight,
            verseText: highlightText,
            isLoading: quranProvider.isLoading && !quranProvider.isLoaded,
            onRead: () =>
                _showQuranSheet(context, quranProvider, highlight: highlight),
            onShare: () => _shareQuranHighlight(highlight, highlightText),
          ),
          const SizedBox(height: 16),
          _HadithStoryCard(
            story: hadithStory,
            onShare: () => _shareHadithStory(hadithStory),
            onIdeas: () => _showStoryIdeas(context),
          ),
          const SizedBox(height: 16),
          const _CommunityAnnouncementsSection(),
          const SizedBox(height: 24),
        ];

        if (groups.isEmpty) {
          return Scaffold(
            backgroundColor: colorScheme.surface,
            body: RefreshIndicator(
              onRefresh: () async {
                await userProvider.refreshUser();
              },
              child: ListView(
                padding: EdgeInsets.symmetric(
                  horizontal: MediaQuery.of(context).size.width > 600 ? 24 : 16,
                  vertical: MediaQuery.of(context).size.height > 800 ? 24 : 16,
                ),
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Home',
                        style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: colorScheme.onSurface,
                            ),
                      ),
                      RefreshButton(
                        onRefresh: () async {
                          await userProvider.refreshUser();
                        },
                        tooltip: 'Refresh',
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  ...baseSections,
                  const _NoGroupsCard(),
                ],
              ),
            ),
          );
        }

        final activeGroup = groups.firstWhere(
          (group) => group.id == _selectedGroupId,
          orElse: () => groups.first,
        );

        return Scaffold(
          backgroundColor: colorScheme.surface,
          body: RefreshIndicator(
            onRefresh: () async {
              await userProvider.refreshUser();
            },
            child: ListView(
              padding: EdgeInsets.symmetric(
                horizontal: MediaQuery.of(context).size.width > 600 ? 24 : 16,
                vertical: MediaQuery.of(context).size.height > 800 ? 24 : 16,
              ),
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Home',
                      style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: colorScheme.onSurface,
                          ),
                    ),
                    RefreshButton(
                      onRefresh: () async {
                        await userProvider.refreshUser();
                      },
                      tooltip: 'Refresh',
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                ...baseSections,
              _GroupSelectorCard(
                groups: groups,
                selectedGroupId: activeGroup.id,
                onChanged: (groupId) {
                  setState(() {
                    _selectedGroupId = groupId;
                  });
                  userProvider.setActiveGroup(groupId);
                },
              ),
              const SizedBox(height: 16),
              _AnnouncementComposer(
                controller: _announcementController,
                focusNode: _announcementFocusNode,
                isPosting: _isPosting,
                isHadith: _isHadith,
                onHadithChanged: (value) {
                  setState(() {
                    _isHadith = value;
                    if (value && _announcementController.text.trim().isEmpty) {
                      _announcementController.text =
                          '“The best among you are those who learn the Qur\'an and teach it.” – Sahih al-Bukhari';
                    }
                  });
                },
                onSubmit: () => _postAnnouncement(
                  group: activeGroup,
                  userProvider: userProvider,
                ),
              ),
              const SizedBox(height: 16),
              _AnnouncementsSection(group: activeGroup),
              const SizedBox(height: 24),
              _AssignmentsSection(
                group: activeGroup,
                userProvider: userProvider,
              ),
            ],
          ),
        ),
      );
    },
    );
  }
}

class _GroupSelectorCard extends StatelessWidget {
  const _GroupSelectorCard({
    required this.groups,
    required this.selectedGroupId,
    required this.onChanged,
  });

  final List<Group> groups;
  final String selectedGroupId;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isSmallScreen = MediaQuery.of(context).size.height < 700;
    return Card(
      elevation: 0,
      child: Padding(
        padding: EdgeInsets.all(isSmallScreen ? 16 : 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'My recitation group',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontSize: isSmallScreen ? 16 : null,
              ),
            ),
            SizedBox(height: isSmallScreen ? 8 : 12),
            InputDecorator(
              decoration: const InputDecoration(
                labelText: 'Select group',
                prefixIcon: Icon(Icons.groups_2),
                border: OutlineInputBorder(),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: selectedGroupId,
                  isExpanded: true,
                      items: groups
                          .map(
                            (group) => DropdownMenuItem(
                              value: group.id,
                              child: Text(
                                group.name,
                                overflow: TextOverflow.ellipsis,
                                maxLines: 1,
                              ),
                            ),
                          )
                          .toList(),
                  onChanged: (value) {
                    if (value != null) {
                      onChanged(value);
                    }
                  },
                ),
              ),
            ),
            SizedBox(height: isSmallScreen ? 8 : 12),
            Text(
              'Share reminders, hadith, or new assignments so everyone stays aligned.',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                fontSize: isSmallScreen ? 13 : null,
              ),
            ),
            SizedBox(height: isSmallScreen ? 12 : 16),
            Text(
              'Tip: use the Groups tab to invite members or assign new recitations, '
              'and the Statistics tab to monitor overall progress.',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                fontSize: isSmallScreen ? 11 : null,
                color: colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AnnouncementComposer extends StatelessWidget {
  const _AnnouncementComposer({
    required this.controller,
    this.focusNode,
    required this.isPosting,
    required this.isHadith,
    required this.onHadithChanged,
    required this.onSubmit,
  });

  final TextEditingController controller;
  final FocusNode? focusNode;
  final bool isPosting;
  final bool isHadith;
  final ValueChanged<bool> onHadithChanged;
  final VoidCallback onSubmit;

  @override
  Widget build(BuildContext context) {
    final isSmallScreen = MediaQuery.of(context).size.height < 700;
    return Card(
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
              controller: controller,
              focusNode: focusNode,
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
            SizedBox(height: isSmallScreen ? 8 : 12),
            SwitchListTile.adaptive(
              value: isHadith,
              onChanged: onHadithChanged,
              title: const Text('Mark as Hadith / Qur’anic reflection'),
            ),
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: isPosting ? null : onSubmit,
              icon: isPosting
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
    );
  }
}

class _AnnouncementsSection extends StatelessWidget {
  const _AnnouncementsSection({required this.group});

  final Group group;

  @override
  Widget build(BuildContext context) {
    final firestore = context.read<FirestoreService>();
    final isSmallScreen = MediaQuery.of(context).size.height < 700;
    return StreamBuilder<List<GroupAnnouncement>>(
      stream: firestore.watchAnnouncements(group.id),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Card(
            elevation: 0,
            child: Padding(
              padding: EdgeInsets.all(isSmallScreen ? 16 : 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Announcements & reflections',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontSize: isSmallScreen ? 16 : null,
                    ),
                  ),
                  SizedBox(height: isSmallScreen ? 8 : 12),
                  Text(
                    'Error loading announcements: ${snapshot.error}',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      fontSize: isSmallScreen ? 13 : null,
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                ],
              ),
            ),
          );
        }

        final announcements = snapshot.data ?? [];
        final isLoading = snapshot.connectionState == ConnectionState.waiting;

        return Card(
          elevation: 0,
          child: Padding(
            padding: EdgeInsets.all(isSmallScreen ? 16 : 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Announcements & reflections',
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontSize: isSmallScreen ? 16 : null,
                        ),
                      ),
                    ),
                    if (isLoading)
                      const SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                  ],
                ),
                const SizedBox(height: 12),
                if (announcements.isEmpty)
                  const Text(
                    'No announcements yet. Share a quick reminder or inspiration for your group.',
                  )
                else ...[
                  ...announcements.take(3).map(
                    (announcement) => Padding(
                      padding: const EdgeInsets.only(bottom: 16),
                      child: _AnnouncementTile(announcement: announcement),
                    ),
                  ),
                  if (announcements.length > 3)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: TextButton.icon(
                        onPressed: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => _AllAnnouncementsScreen(
                                group: group,
                              ),
                            ),
                          );
                        },
                        icon: const Icon(Icons.visibility),
                        label: Text(
                          'See ${announcements.length - 3} more announcement${announcements.length - 3 == 1 ? '' : 's'}',
                        ),
                      ),
                    ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }
}

class _AnnouncementTile extends StatelessWidget {
  const _AnnouncementTile({required this.announcement});

  final GroupAnnouncement announcement;

  // TODO: File sharing temporarily disabled - Firebase/Firestore not supporting file storage for now
  // Enable this when Firebase Storage is properly configured
  /*
  Future<void> _downloadFile(BuildContext context, FileAttachment attachment) async {
    try {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Downloading file...')),
      );

      final response = await http.get(Uri.parse(attachment.url));
      if (response.statusCode == 200) {
        final directory = await getApplicationDocumentsDirectory();
        final file = File('${directory.path}/${attachment.fileName}');
        await file.writeAsBytes(response.bodyBytes);
        
        await OpenFilex.open(file.path);
        
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('File saved: ${attachment.fileName}')),
          );
        }
      } else {
        throw Exception('Failed to download file');
      }
    } catch (e) {
      if (context.mounted) {
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
  Future<void> _downloadFile(BuildContext context, FileAttachment attachment) async {
    // File sharing temporarily disabled
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final theme = Theme.of(context);
    final isSmallScreen = MediaQuery.of(context).size.height < 700;
    final createdAt = DateFormat(
      'MMM d • h:mm a',
    ).format(announcement.createdAt);

    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        color: announcement.isHadith
            ? colorScheme.primaryContainer
            : colorScheme.surfaceContainerHigh,
      ),
      child: Padding(
        padding: EdgeInsets.all(isSmallScreen ? 12 : 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  announcement.isHadith
                      ? Icons.auto_stories
                      : Icons.campaign_outlined,
                  color: announcement.isHadith
                      ? colorScheme.primary
                      : colorScheme.secondary,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    announcement.authorName.isEmpty
                        ? 'Group announcement'
                        : announcement.authorName,
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                      fontSize: isSmallScreen ? 13 : null,
                    ),
                  ),
                ),
                Text(
                  createdAt,
                  style: theme.textTheme.bodySmall?.copyWith(
                    fontSize: isSmallScreen ? 10 : null,
                  ),
                ),
              ],
            ),
            SizedBox(height: isSmallScreen ? 8 : 12),
            Text(
              announcement.message,
              style: theme.textTheme.bodyMedium?.copyWith(
                height: 1.4,
                fontSize: isSmallScreen ? 13 : null,
              ),
            ),
            // TODO: File sharing temporarily disabled - Firebase/Firestore not supporting file storage for now
            // Enable this when Firebase Storage is properly configured
            /*
            if (announcement.attachments.isNotEmpty) ...[
              SizedBox(height: isSmallScreen ? 8 : 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: announcement.attachments.map((attachment) {
                  return Card(
                    elevation: 0,
                    color: colorScheme.surfaceContainerHigh,
                    child: InkWell(
                      onTap: () {
                        // Open/download file
                        _downloadFile(context, attachment);
                      },
                      child: Padding(
                        padding: EdgeInsets.all(isSmallScreen ? 8 : 12),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              attachment.isImage
                                  ? Icons.image
                                  : attachment.isPdf
                                      ? Icons.picture_as_pdf
                                      : Icons.description,
                              size: isSmallScreen ? 20 : 24,
                            ),
                            SizedBox(width: isSmallScreen ? 6 : 8),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  attachment.fileName,
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    fontSize: isSmallScreen ? 11 : null,
                                    fontWeight: FontWeight.w500,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                Text(
                                  StorageService.formatFileSize(attachment.fileSize),
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    fontSize: isSmallScreen ? 9 : null,
                                  ),
                                ),
                              ],
                            ),
                            SizedBox(width: isSmallScreen ? 4 : 6),
                            Icon(
                              Icons.download,
                              size: isSmallScreen ? 16 : 18,
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ],
            */
          ],
        ),
      ),
    );
  }
}

class _AssignmentsSection extends StatefulWidget {
  const _AssignmentsSection({required this.group, required this.userProvider});

  final Group group;
  final UserProvider userProvider;

  @override
  State<_AssignmentsSection> createState() => _AssignmentsSectionState();
}

class _AssignmentsSectionState extends State<_AssignmentsSection> {
  bool _showAllGroups = false;
  bool _showAllAssignments = false;
  bool _showCelebration = false;
  final Set<String> _removingAssignments = {}; // Track assignments being removed
  static const int _maxInitialAssignments = 3;

  @override
  Widget build(BuildContext context) {
    final firestore = context.read<FirestoreService>();
    final user = widget.userProvider.user;

    if (user == null) {
      return const SizedBox.shrink();
    }

    return StreamBuilder<List<RecitationAssignment>>(
      stream: _showAllGroups
          ? firestore.watchMemberAssignments(user.uid)
          : firestore.watchMemberAssignments(user.uid, groupId: widget.group.id),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Card(
            elevation: 0,
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'My assignments${_showAllGroups ? '' : ' for ${widget.group.name}'}',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Error loading assignments: ${snapshot.error}',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                ],
              ),
            ),
          );
        }

        final allAssignments = snapshot.data ?? [];
        // Filter out completed assignments - they should only appear in history
        final activeAssignments = allAssignments
            .where((assignment) => !assignment.isCompleted && !_removingAssignments.contains(assignment.id))
            .toList();
        final completed = allAssignments
            .where((assignment) => assignment.isCompleted)
            .length;
        final pending = activeAssignments
            .where((assignment) => assignment.status == 'pending')
            .length;
        final ongoing = activeAssignments
            .where((assignment) => assignment.status == 'ongoing')
            .length;
        final totalActive = activeAssignments.length;
        final totalAll = allAssignments.length;
        final completionRate = totalAll == 0
            ? 0.0
            : completed / totalAll;

        final isSmallScreen = MediaQuery.of(context).size.height < 700;
        return Stack(
          children: [
            Card(
              elevation: 0,
              child: Padding(
                padding: EdgeInsets.all(isSmallScreen ? 16 : 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            'My assignments${_showAllGroups ? ' (All groups)' : ' for ${widget.group.name}'}',
                            overflow: TextOverflow.ellipsis,
                            maxLines: 2,
                            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              fontSize: isSmallScreen ? 16 : null,
                            ),
                          ),
                        ),
                        IconButton(
                          icon: Icon(
                            _showAllGroups ? Icons.filter_list : Icons.filter_list_off,
                            size: isSmallScreen ? 20 : 24,
                          ),
                          tooltip: _showAllGroups ? 'Show only this group' : 'Show all groups',
                          onPressed: () {
                            setState(() {
                              _showAllGroups = !_showAllGroups;
                            });
                          },
                        ),
                      ],
                    ),
                    SizedBox(height: isSmallScreen ? 12 : 16),
                    LinearProgressIndicator(
                      value: completionRate,
                      minHeight: isSmallScreen ? 8 : 10,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    SizedBox(height: isSmallScreen ? 8 : 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _SummaryChip(
                      label: 'Active',
                      value: totalActive,
                      color: Theme.of(context).colorScheme.primaryContainer,
                    ),
                    _SummaryChip(
                      label: 'Pending',
                      value: pending,
                      color: Theme.of(context).colorScheme.tertiaryContainer,
                    ),
                    _SummaryChip(
                      label: 'In Progress',
                      value: ongoing,
                      color: Theme.of(context).colorScheme.secondaryContainer,
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                if (snapshot.connectionState == ConnectionState.waiting)
                  const Center(
                    child: Padding(
                      padding: EdgeInsets.all(24),
                      child: CircularProgressIndicator(),
                    ),
                  )
                else if (activeAssignments.isEmpty)
                  Card(
                    elevation: 0,
                    color: Theme.of(context).colorScheme.surfaceContainerHighest,
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        children: [
                          Icon(
                            Icons.check_circle_outline,
                            color: Theme.of(context).colorScheme.primary,
                            size: isSmallScreen ? 32 : 40,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'All active assignments completed! 🎉',
                                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                                    fontWeight: FontWeight.w600,
                                    fontSize: isSmallScreen ? 14 : null,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  totalAll > 0
                                      ? 'View your completed recitations in the History tab.'
                                      : (_showAllGroups
                                          ? 'No assignments found across all your groups. Once an admin assigns a recitation it will appear here.'
                                          : 'No assignments yet for ${widget.group.name}. Once the admin assigns a recitation it will appear here.'),
                                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                    fontSize: isSmallScreen ? 12 : null,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                else ...[
                  ...(_showAllAssignments 
                      ? activeAssignments 
                      : activeAssignments.take(_maxInitialAssignments)).map(
                    (assignment) => AnimatedSize(
                      duration: const Duration(milliseconds: 300),
                      curve: Curves.easeInOut,
                      child: _removingAssignments.contains(assignment.id)
                          ? const SizedBox.shrink()
                          : AnimatedOpacity(
                              duration: const Duration(milliseconds: 250),
                              opacity: _removingAssignments.contains(assignment.id) ? 0.0 : 1.0,
                              child: Padding(
                                padding: const EdgeInsets.symmetric(vertical: 8),
                                child: TodoItem(
                                  assignment: assignment,
                                  onMarkCompleted: () async {
                                    // Mark as removing to trigger animation
                                    setState(() {
                                      _removingAssignments.add(assignment.id);
                                    });
                                    
                                    // Wait for animation
                                    await Future.delayed(const Duration(milliseconds: 300));
                                    
                                    // Update status in Firestore
                                    await firestore.updateRecitationStatus(
                                      assignment: assignment,
                                      status: 'completed',
                                    );
                                    
                                    // Remove from removing set after stream updates
                                    if (mounted) {
                                      setState(() {
                                        _removingAssignments.remove(assignment.id);
                                      });
                                    }
                                    
                                    final notificationService = context.read<NotificationService>();
                                    await notificationService.showLocalNotification(
                                      'Assignment completed',
                                      'You have completed ${assignment.surah ?? 'Juz ${assignment.juzNumber}'}.',
                                    );
                                    
                                    // Show success snackbar with option to view in history
                                    if (mounted) {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(
                                          content: Row(
                                            children: [
                                              const Icon(Icons.check_circle, color: Colors.white),
                                              const SizedBox(width: 12),
                                              Expanded(
                                                child: Text(
                                                  '${assignment.surah ?? 'Juz ${assignment.juzNumber}'} completed!',
                                                  style: const TextStyle(fontWeight: FontWeight.w500),
                                                ),
                                              ),
                                            ],
                                          ),
                                          backgroundColor: Theme.of(context).colorScheme.primary,
                                          behavior: SnackBarBehavior.floating,
                                          duration: const Duration(seconds: 3),
                                          action: SnackBarAction(
                                            label: 'View History',
                                            textColor: Colors.white,
                                            onPressed: () {
                                              // Navigate to history tab (index 2)
                                              try {
                                                final tabSwitcher = context.read<ValueChanged<int>>();
                                                tabSwitcher(2); // History tab is at index 2
                                              } catch (_) {
                                                // If provider not available, show message
                                                ScaffoldMessenger.of(context).showSnackBar(
                                                  const SnackBar(
                                                    content: Text('Switch to History tab to view completed recitations'),
                                                    duration: Duration(seconds: 2),
                                                  ),
                                                );
                                              }
                                            },
                                          ),
                                        ),
                                      );
                                    }
                                    
                                    // Check if all 30 Juz are completed for this week
                                    if (assignment.weekId != null) {
                                      final weeklyService = WeeklyAssignmentService(FirebaseFirestore.instance);
                                      final isComplete = await weeklyService.isWeekComplete(
                                        groupId: assignment.groupId,
                                        weekId: assignment.weekId!,
                                      );
                                      
                                      if (isComplete && mounted) {
                                        setState(() {
                                          _showCelebration = true;
                                        });
                                        
                                        // Auto-create next week if current week is complete
                                        try {
                                          await weeklyService.checkAndCreateNextWeek(
                                            groupId: assignment.groupId,
                                            completedWeekId: assignment.weekId!,
                                          );
                                          if (mounted) {
                                            ScaffoldMessenger.of(context).showSnackBar(
                                              SnackBar(
                                                content: const Row(
                                                  children: [
                                                    Icon(Icons.celebration, color: Colors.white),
                                                    SizedBox(width: 12),
                                                    Expanded(
                                                      child: Text(
                                                        'Week completed! New week assignments created automatically.',
                                                        style: TextStyle(fontWeight: FontWeight.w500),
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                                backgroundColor: Colors.green,
                                                behavior: SnackBarBehavior.floating,
                                                duration: const Duration(seconds: 4),
                                              ),
                                            );
                                          }
                                        } catch (e) {
                                          // Silently fail - next week might already exist
                                        }
                                        
                                        // Hide celebration after 3 seconds
                                        Future.delayed(const Duration(seconds: 3), () {
                                          if (mounted) {
                                            setState(() {
                                              _showCelebration = false;
                                            });
                                          }
                                        });
                                      }
                                    }
                                  },
                                  onMarkInProgress: assignment.status == 'ongoing'
                                      ? null
                                      : () async {
                                          await firestore.updateRecitationStatus(
                                            assignment: assignment,
                                            status: 'ongoing',
                                          );
                                          final notificationService = context.read<NotificationService>();
                                          await notificationService.showLocalNotification(
                                            'Assignment in progress',
                                            'You are working on ${assignment.surah ?? 'Juz ${assignment.juzNumber}'}.',
                                          );
                                        },
                                  onReset: assignment.status == 'pending'
                                      ? null
                                      : () async {
                                          await firestore.updateRecitationStatus(
                                            assignment: assignment,
                                            status: 'pending',
                                          );
                                        },
                                ),
                              ),
                            ),
                    ),
                  ),
                  if (!_showAllAssignments && activeAssignments.length > _maxInitialAssignments)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Center(
                        child: OutlinedButton.icon(
                          onPressed: () {
                            setState(() {
                              _showAllAssignments = true;
                            });
                          },
                          icon: const Icon(Icons.expand_more),
                          label: Text(
                            'Show ${activeAssignments.length - _maxInitialAssignments} more assignment${activeAssignments.length - _maxInitialAssignments == 1 ? '' : 's'}',
                          ),
                        ),
                      ),
                    )
                  else if (_showAllAssignments && activeAssignments.length > _maxInitialAssignments)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Center(
                        child: OutlinedButton.icon(
                          onPressed: () {
                            setState(() {
                              _showAllAssignments = false;
                            });
                          },
                          icon: const Icon(Icons.expand_less),
                          label: const Text('Show less'),
                        ),
                      ),
                    ),
                ],
              ],
            ),
          ),
        ),
            if (_showCelebration)
              Positioned.fill(
                child: CelebrationWidget(
                  onComplete: () {
                    if (mounted) {
                      setState(() {
                        _showCelebration = false;
                      });
                    }
                  },
                ),
              ),
          ],
        );
      },
    );
  }
}

class _SummaryChip extends StatelessWidget {
  const _SummaryChip({
    required this.label,
    required this.value,
    required this.color,
    this.suffix,
  });

  final String label;
  final int value;
  final Color color;
  final String? suffix;

  @override
  Widget build(BuildContext context) {
    return Chip(
      backgroundColor: color,
      labelPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      label: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '$value${suffix ?? ''}',
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
          ),
          Text(label),
        ],
      ),
    );
  }
}

class _NoGroupsCard extends StatelessWidget {
  const _NoGroupsCard();

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    ValueChanged<int>? goToGroups;
    try {
      goToGroups = Provider.of<ValueChanged<int>>(context, listen: false);
    } catch (_) {
      goToGroups = null;
    }
    final isSmallScreen = MediaQuery.of(context).size.height < 700;
    return Card(
      elevation: 0,
      child: Padding(
        padding: EdgeInsets.all(isSmallScreen ? 16 : 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.group_add_outlined,
                  color: colorScheme.primary,
                  size: isSmallScreen ? 24 : 32,
                ),
                const SizedBox(width: 12),
                Text(
                  'Bring your community together',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ],
            ),
            const SizedBox(height: 12),
            const Text(
              'Create a recitation circle or join one using an invite code. '
              'Once you are part of a group, your announcements and assignments will appear here automatically.',
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: goToGroups != null
                  ? () => goToGroups!.call(1)
                  : () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text(
                            'Use the Groups tab to create or join your first circle.',
                          ),
                        ),
                      );
                    },
              icon: const Icon(Icons.groups),
              label: const Text('Create or join a group'),
            ),
          ],
        ),
      ),
    );
  }
}

class _QuranHighlightCard extends StatelessWidget {
  const _QuranHighlightCard({
    required this.highlight,
    required this.verseText,
    required this.isLoading,
    required this.onRead,
    required this.onShare,
  });

  final _QuranHighlight highlight;
  final String verseText;
  final bool isLoading;
  final VoidCallback onRead;
  final VoidCallback onShare;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final trimmed = verseText.trim();

    final isSmallScreen = MediaQuery.of(context).size.height < 700;
    return Card(
      elevation: 0,
      child: Padding(
        padding: EdgeInsets.all(isSmallScreen ? 16 : 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.menu_book_outlined,
                  color: colorScheme.primary,
                  size: isSmallScreen ? 20 : 24,
                ),
                SizedBox(width: isSmallScreen ? 8 : 12),
                Expanded(
                  child: Text(
                    'Qur\'an highlight • ${highlight.caption}',
                    overflow: TextOverflow.ellipsis,
                    maxLines: 2,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontSize: isSmallScreen ? 16 : null,
                    ),
                  ),
                ),
              ],
            ),
            SizedBox(height: isSmallScreen ? 8 : 12),
            if (isLoading)
              const LinearProgressIndicator()
            else if (trimmed.isEmpty)
              const Text(
                'Verses unavailable right now. Pull to refresh to try again.',
              )
            else
              Text(
                trimmed,
                textDirection: ui.TextDirection.rtl,
                style: theme.textTheme.titleMedium?.copyWith(
                  height: 1.6,
                  fontWeight: FontWeight.w600,
                  fontSize: isSmallScreen ? 14 : null,
                ),
              ),
            SizedBox(height: isSmallScreen ? 12 : 16),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                FilledButton.icon(
                  onPressed: onRead,
                  icon: const Icon(Icons.menu_book),
                  label: Text('Read ${highlight.surah}'),
                ),
                OutlinedButton.icon(
                  onPressed: trimmed.isEmpty ? null : onShare,
                  icon: const Icon(Icons.share),
                  label: const Text('Share with group'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _HadithStoryCard extends StatelessWidget {
  const _HadithStoryCard({
    required this.story,
    required this.onShare,
    required this.onIdeas,
  });

  final _HadithStory story;
  final VoidCallback onShare;
  final VoidCallback onIdeas;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isSmallScreen = MediaQuery.of(context).size.height < 700;
    return Card(
      elevation: 0,
      child: Padding(
        padding: EdgeInsets.all(isSmallScreen ? 16 : 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.auto_stories_outlined, color: colorScheme.secondary),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    story.title,
                    overflow: TextOverflow.ellipsis,
                    maxLines: 2,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontSize: isSmallScreen ? 16 : null,
                    ),
                  ),
                ),
              ],
            ),
            SizedBox(height: isSmallScreen ? 6 : 8),
            Text(
              'Narrated by ${story.narratedBy}',
              style: theme.textTheme.bodySmall?.copyWith(
                fontSize: isSmallScreen ? 11 : null,
                color: colorScheme.onSurfaceVariant,
              ),
            ),
            SizedBox(height: isSmallScreen ? 8 : 12),
            Text(
              '"${story.quote}"',
              style: theme.textTheme.titleMedium?.copyWith(
                height: 1.5,
                fontSize: isSmallScreen ? 14 : null,
              ),
            ),
            SizedBox(height: isSmallScreen ? 8 : 12),
            Text(
              story.reflection,
              style: theme.textTheme.bodyMedium?.copyWith(
                fontSize: isSmallScreen ? 13 : null,
              ),
            ),
            SizedBox(height: isSmallScreen ? 12 : 16),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                FilledButton.icon(
                  onPressed: onShare,
                  icon: const Icon(Icons.send),
                  label: const Text('Share this reminder'),
                ),
                OutlinedButton.icon(
                  onPressed: onIdeas,
                  icon: const Icon(Icons.lightbulb_outline),
                  label: const Text('More story ideas'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _CommunityAnnouncementsSection extends StatelessWidget {
  const _CommunityAnnouncementsSection();

  @override
  Widget build(BuildContext context) {
    final firestore = context.read<FirestoreService>();
    final isSmallScreen = MediaQuery.of(context).size.height < 700;
    return StreamBuilder<List<AppAnnouncement>>(
      stream: firestore.watchCommunityAnnouncements(limit: 5),
      builder: (context, snapshot) {
        final announcements = snapshot.data ?? [];
        final isLoading = snapshot.connectionState == ConnectionState.waiting;
        return Card(
          elevation: 0,
          child: Padding(
            padding: EdgeInsets.all(isSmallScreen ? 16 : 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Community announcements',
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontSize: isSmallScreen ? 16 : null,
                        ),
                      ),
                    ),
                    if (isLoading)
                      const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                  ],
                ),
                const SizedBox(height: 12),
                if (announcements.isEmpty && isLoading)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 16),
                    child: Center(child: CircularProgressIndicator()),
                  )
                else if (announcements.isEmpty)
                  const Text(
                    'No community-wide announcements yet. Your administrators can publish reminders here for everyone.',
                  )
                else
                  ...announcements
                      .take(3)
                      .map(
                        (announcement) => Padding(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          child: ListTile(
                            contentPadding: EdgeInsets.zero,
                            title: Text(announcement.title),
                            subtitle: Text(
                              announcement.body,
                              style: Theme.of(
                                context,
                              ).textTheme.bodyMedium?.copyWith(height: 1.4),
                            ),
                            trailing: Text(
                              DateFormat(
                                'MMM d, y',
                              ).format(announcement.publishedAt),
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                          ),
                        ),
                      ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _QuranHighlight {
  const _QuranHighlight({
    required this.surah,
    required this.ayahRange,
    required this.caption,
  });

  final String surah;
  final String ayahRange;
  final String caption;
}

class _HadithStory {
  const _HadithStory({
    required this.title,
    required this.narratedBy,
    required this.quote,
    required this.reflection,
  });

  final String title;
  final String narratedBy;
  final String quote;
  final String reflection;
}

class _AllAnnouncementsScreen extends StatelessWidget {
  const _AllAnnouncementsScreen({required this.group});

  final Group group;

  @override
  Widget build(BuildContext context) {
    final firestore = context.read<FirestoreService>();
    final isSmallScreen = MediaQuery.of(context).size.height < 700;
    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'All Announcements',
              style: TextStyle(fontSize: isSmallScreen ? 16 : null),
            ),
            Text(
              group.name,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    fontSize: isSmallScreen ? 11 : null,
                    color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
                  ),
            ),
          ],
        ),
      ),
      body: StreamBuilder<List<GroupAnnouncement>>(
        stream: firestore.watchAnnouncements(group.id),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: EdgeInsets.all(isSmallScreen ? 16 : 24),
                child: Text(
                  'Error loading announcements: ${snapshot.error}',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Theme.of(context).colorScheme.error,
                      ),
                ),
              ),
            );
          }

          final announcements = snapshot.data ?? [];
          final isLoading = snapshot.connectionState == ConnectionState.waiting;

          if (isLoading) {
            return const Center(child: CircularProgressIndicator());
          }

          if (announcements.isEmpty) {
            return Center(
              child: Padding(
                padding: EdgeInsets.all(isSmallScreen ? 16 : 24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.campaign_outlined,
                      size: isSmallScreen ? 48 : 64,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                    SizedBox(height: isSmallScreen ? 12 : 16),
                    Text(
                      'No announcements yet',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontSize: isSmallScreen ? 16 : null,
                      ),
                    ),
                    SizedBox(height: isSmallScreen ? 6 : 8),
                    Text(
                      'Share a quick reminder or inspiration for your group.',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            fontSize: isSmallScreen ? 13 : null,
                            color: Theme.of(context).colorScheme.onSurfaceVariant,
                          ),
                    ),
                  ],
                ),
              ),
            );
          }

          return RefreshIndicator(
            onRefresh: () async {
              // The stream will automatically update
              await Future.delayed(const Duration(milliseconds: 500));
            },
            child: ListView(
              padding: EdgeInsets.all(isSmallScreen ? 12 : 16),
              children: [
                ...announcements.map(
                  (announcement) => Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: _AnnouncementTile(announcement: announcement),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _HadithLibrary {
  static const List<_HadithStory> _stories = [
    _HadithStory(
      title: 'Seeking knowledge',
      narratedBy: 'Anas ibn Malik (ra)',
      quote:
          'Whoever follows a path in pursuit of knowledge, Allah will make easy for him a path to Paradise.',
      reflection:
          'Invite your group to share one insight from this week’s recitation or study circle so that knowledge spreads among everyone.',
    ),
    _HadithStory(
      title: 'Consistency matters',
      narratedBy: 'Aisha (ra)',
      quote:
          'The most beloved deeds to Allah are those that are consistent, even if small.',
      reflection:
          'Encourage members to commit to a manageable daily portion, reminding them that steady effort leads to lasting transformation.',
    ),
    _HadithStory(
      title: 'Brotherhood and support',
      narratedBy: 'Abdullah ibn Umar (ra)',
      quote:
          'A Muslim is the brother of a Muslim; he neither oppresses him nor abandons him.',
      reflection:
          'Check in on a group member who has been quiet lately and offer to review their recitation together for encouragement.',
    ),
    _HadithStory(
      title: 'Intentions first',
      narratedBy: 'Umar ibn Al-Khattab (ra)',
      quote:
          'Actions are judged by intentions, and every person will have what they intended.',
      reflection:
          'Before your next gathering, renew your intention that it is purely for Allah’s pleasure and to strengthen each other in the Qur’an.',
    ),
  ];

  static _HadithStory storyForDate(DateTime date) {
    if (_stories.isEmpty) {
      return const _HadithStory(
        title: 'Daily reminder',
        narratedBy: 'Unknown',
        quote: 'Remember Allah and He will remember you.',
        reflection:
            'Use this space to share a heartfelt reminder with your group.',
      );
    }
    final startOfYear = DateTime(date.year);
    final dayIndex = date.difference(startOfYear).inDays;
    final index = dayIndex % _stories.length;
    return _stories[index];
  }
}

