import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../providers/user_provider.dart';
import '../../providers/theme_provider.dart';
import '../../services/firestore_service.dart';
import '../../models/recitation_model.dart';
import '../../widgets/refresh_button.dart';
import '../../widgets/theme_toggle_button.dart';

// Replace with your actual website URL
const String developerWebsite = 'https://your-website.com';

class ProfileTab extends StatefulWidget {
  const ProfileTab({super.key});

  @override
  State<ProfileTab> createState() => _ProfileTabState();
}

class _ProfileTabState extends State<ProfileTab> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _usernameController;
  late final TextEditingController _countryController;
  late final TextEditingController _cityController;
  late final TextEditingController _bioController;

  bool _isSaving = false;
  bool _hasSeededInitialValues = false;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController();
    _usernameController = TextEditingController();
    _countryController = TextEditingController();
    _cityController = TextEditingController();
    _bioController = TextEditingController();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _usernameController.dispose();
    _countryController.dispose();
    _cityController.dispose();
    _bioController.dispose();
    super.dispose();
  }

  void _seedFormFromUser(UserProvider provider) {
    final user = provider.user;
    if (user == null || (_hasSeededInitialValues && !_isSaving)) {
      return;
    }
    _nameController.text = user.name;
    _usernameController.text = user.username ?? '';
    _countryController.text = user.country ?? '';
    _cityController.text = user.city ?? '';
    _bioController.text = user.bio ?? '';
    _hasSeededInitialValues = true;
  }

  String _valueOrEmpty(String? value) => value?.trim() ?? '';

  Future<void> _saveProfile() async {
    if (_isSaving) {
      return;
    }
    if (!_formKey.currentState!.validate()) {
      return;
    }

    final provider = context.read<UserProvider>();
    final user = provider.user;

    final name = _nameController.text.trim();
    final username = _usernameController.text.trim();
    final country = _countryController.text.trim();
    final city = _cityController.text.trim();
    final bio = _bioController.text.trim();

    final previousName = _valueOrEmpty(user?.name);
    final previousUsername = _valueOrEmpty(user?.username);
    final previousCountry = _valueOrEmpty(user?.country);
    final previousCity = _valueOrEmpty(user?.city);
    final previousBio = _valueOrEmpty(user?.bio);

    final hasChanges =
        name != previousName ||
        username != previousUsername ||
        country != previousCountry ||
        city != previousCity ||
        bio != previousBio;

    if (!hasChanges) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No profile changes to save.')),
      );
      return;
    }

    setState(() => _isSaving = true);
    await provider.updateProfile(
      displayName: name,
      username: username,
      country: country,
      city: city,
      bio: bio,
    );

    if (!mounted) {
      return;
    }

    setState(() {
      _isSaving = false;
      _hasSeededInitialValues = false;
    });

    final error = provider.errorMessage;
    if (error != null && error.isNotEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(error),
          backgroundColor: Theme.of(context).colorScheme.error,
        ),
      );
    } else {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Profile updated')));
    }
  }

  void _copyUserId(String uid) {
    Clipboard.setData(ClipboardData(text: uid));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('User ID copied to clipboard')),
    );
  }

  void _showDeveloperInfo(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isSmallScreen = MediaQuery.of(context).size.height < 700;
    
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        expand: false,
        builder: (context, scrollController) => SingleChildScrollView(
          controller: scrollController,
          child: Padding(
            padding: EdgeInsets.all(isSmallScreen ? 20 : 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    margin: const EdgeInsets.only(bottom: 20),
                    decoration: BoxDecoration(
                      color: colorScheme.onSurfaceVariant.withOpacity(0.4),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                Row(
                  children: [
                    Container(
                      width: isSmallScreen ? 60 : 80,
                      height: isSmallScreen ? 60 : 80,
                      decoration: BoxDecoration(
                        color: colorScheme.primaryContainer,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.person,
                        size: isSmallScreen ? 30 : 40,
                        color: colorScheme.primary,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Ali Kibret',
                            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                                  fontWeight: FontWeight.bold,
                                  fontSize: isSmallScreen ? 20 : null,
                                ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Academic Research Assistant',
                            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                  color: colorScheme.primary,
                                  fontSize: isSmallScreen ? 14 : null,
                                ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Adama Science and Technology University (ASTU)',
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                  color: colorScheme.onSurfaceVariant,
                                  fontSize: isSmallScreen ? 11 : null,
                                ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                Container(
                  padding: EdgeInsets.all(isSmallScreen ? 16 : 20),
                  decoration: BoxDecoration(
                    color: colorScheme.primaryContainer.withOpacity(0.3),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'About This App',
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w600,
                              fontSize: isSmallScreen ? 16 : null,
                            ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'This application was created specifically for the ASTU Student Muslim Community to facilitate team-based Qur\'an recitation, strengthen Iman through interaction, sharing, and collaborative learning.',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              height: 1.6,
                              fontSize: isSmallScreen ? 13 : null,
                            ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'The app enables students to:',
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.w600,
                              fontSize: isSmallScreen ? 14 : null,
                            ),
                      ),
                      const SizedBox(height: 8),
                      _buildFeatureItem(
                        context,
                        'Recite Qur\'an together in organized groups',
                        Icons.groups,
                        isSmallScreen,
                      ),
                      _buildFeatureItem(
                        context,
                        'Track weekly recitation progress',
                        Icons.track_changes,
                        isSmallScreen,
                      ),
                      _buildFeatureItem(
                        context,
                        'Share reflections and Hadith',
                        Icons.auto_stories,
                        isSmallScreen,
                      ),
                      _buildFeatureItem(
                        context,
                        'Build Iman through community interaction',
                        Icons.favorite,
                        isSmallScreen,
                      ),
                    ],
                  ),
                ),
                if (developerWebsite != 'https://your-website.com') ...[
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: () async {
                        final uri = Uri.parse(developerWebsite);
                        if (await canLaunchUrl(uri)) {
                          await launchUrl(uri, mode: LaunchMode.externalApplication);
                        } else {
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Unable to open website'),
                              ),
                            );
                          }
                        }
                      },
                      icon: const Icon(Icons.language),
                      label: const Text('Visit Developer Website'),
                    ),
                  ),
                ],
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Close'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFeatureItem(
    BuildContext context,
    String text,
    IconData icon,
    bool isSmallScreen,
  ) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Icon(
            icon,
            size: isSmallScreen ? 18 : 20,
            color: Theme.of(context).colorScheme.primary,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              text,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    fontSize: isSmallScreen ? 13 : null,
                  ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<UserProvider>();
    final user = provider.user;

    if (provider.isLoading && user == null) {
      return const Center(child: CircularProgressIndicator());
    }

    if (user == null) {
      Future.microtask(() => provider.refreshUser());
      return const Center(child: CircularProgressIndicator());
    }

    if (!_hasSeededInitialValues) {
      _seedFormFromUser(provider);
    }

    final colorScheme = Theme.of(context).colorScheme;
    final createdAt = user.createdAt;
    final memberSince = createdAt == null
        ? 'Syncing account details…'
        : DateFormat.yMMMMd().format(createdAt);

    final isSmallScreen = MediaQuery.of(context).size.height < 700;
    return ListView(
      padding: EdgeInsets.symmetric(
        horizontal: MediaQuery.of(context).size.width > 600 ? 24 : 16,
        vertical: isSmallScreen ? 16 : 24,
      ),
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Profile',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: colorScheme.onSurface,
                  ),
            ),
            RefreshButton(
              onRefresh: () async {
                await provider.refreshUser();
              },
              tooltip: 'Refresh profile',
            ),
          ],
        ),
        const SizedBox(height: 16),
        Form(
          key: _formKey,
          child: Card(
            elevation: 0,
            child: Padding(
              padding: EdgeInsets.all(isSmallScreen ? 16 : 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      CircleAvatar(
                        radius: isSmallScreen ? 24 : 32,
                        backgroundColor: colorScheme.primaryContainer,
                        child: Text(
                          user.name.isEmpty ? '?' : user.name[0].toUpperCase(),
                          style: Theme.of(context).textTheme.headlineSmall
                              ?.copyWith(fontWeight: FontWeight.bold),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              user.email,
                              style: Theme.of(context).textTheme.bodyMedium,
                            ),
                            const SizedBox(height: 6),
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: [
                                Chip(
                                  avatar: const Icon(
                                    Icons.group_outlined,
                                    size: 16,
                                  ),
                                  label: Text('${user.groups.length} groups'),
                                ),
                                if ((user.username ?? '').isNotEmpty)
                                  Chip(
                                    avatar: const Icon(Icons.tag, size: 16),
                                    label: Text('@${user.username}'),
                                  ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            _TotalJuzCompleted(userId: user.uid),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  TextFormField(
                    controller: _nameController,
                    textCapitalization: TextCapitalization.words,
                    decoration: const InputDecoration(
                      labelText: 'Display name',
                      prefixIcon: Icon(Icons.person),
                    ),
                    validator: (value) {
                      if ((value ?? '').trim().isEmpty) {
                        return 'Please provide your name';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _usernameController,
                    decoration: const InputDecoration(
                      labelText: 'Username',
                      helperText:
                          'Use 3 or more letters/numbers. This helps others find you.',
                      prefixIcon: Icon(Icons.alternate_email),
                    ),
                    textInputAction: TextInputAction.next,
                    validator: (value) {
                      final trimmed = (value ?? '').trim();
                      if (trimmed.isEmpty) {
                        return null;
                      }
                      final regex = RegExp(r'^[a-zA-Z0-9_.-]{3,}$');
                      if (!regex.hasMatch(trimmed)) {
                        return 'Username can include letters, numbers, ".", "_" or "-"';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _countryController,
                    textCapitalization: TextCapitalization.words,
                    decoration: const InputDecoration(
                      labelText: 'Country',
                      prefixIcon: Icon(Icons.public),
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _cityController,
                    textCapitalization: TextCapitalization.words,
                    decoration: const InputDecoration(
                      labelText: 'City / Region',
                      prefixIcon: Icon(Icons.location_city_outlined),
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _bioController,
                    maxLines: 4,
                    maxLength: 280,
                    decoration: const InputDecoration(
                      labelText: 'About you (optional)',
                      alignLabelWithHint: true,
                      prefixIcon: Icon(Icons.notes_outlined),
                    ),
                  ),
                  const SizedBox(height: 24),
                  FilledButton.icon(
                    onPressed: _isSaving ? null : _saveProfile,
                    icon: _isSaving
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.save_outlined),
                    label: const Text('Save profile'),
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 24),
        Card(
          elevation: 0,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.event_available_outlined),
                title: const Text('Member since'),
                subtitle: Text(memberSince),
              ),
              const Divider(height: 0),
              ListTile(
                leading: const Icon(Icons.perm_identity),
                title: const Text('User ID'),
                subtitle: Text(user.uid),
                trailing: IconButton(
                  icon: const Icon(Icons.copy),
                  tooltip: 'Copy user ID',
                  onPressed: () => _copyUserId(user.uid),
                ),
              ),
              const Divider(height: 0),
              ListTile(
                leading: const Icon(Icons.timeline_outlined),
                title: const Text('Activity summary'),
                subtitle: Text(
                  user.groups.isEmpty
                      ? 'You have not joined any recitation groups yet. Join a group from the Groups tab to start tracking your recitation progress.'
                      : 'Active in ${user.groups.length} group${user.groups.length == 1 ? '' : 's'}. Visit the Statistics tab to review your recitation progress and history.',
                ),
              ),
              if ((user.country ?? '').isNotEmpty || (user.city ?? '').isNotEmpty) ...[
                const Divider(height: 0),
                ListTile(
                  leading: const Icon(Icons.location_on_outlined),
                  title: const Text('Location'),
                  subtitle: Text(
                    [
                      if ((user.city ?? '').isNotEmpty) user.city,
                      if ((user.country ?? '').isNotEmpty) user.country,
                    ].where((e) => e != null && e.isNotEmpty).join(', '),

                  ),
                ),
              ],
              if ((user.username ?? '').isNotEmpty) ...[
                const Divider(height: 0),
                ListTile(
                  leading: const Icon(Icons.alternate_email),
                  title: const Text('Username'),
                  subtitle: Text('@${user.username}'),
                  trailing: IconButton(
                    icon: const Icon(Icons.copy),
                    tooltip: 'Copy username',
                    onPressed: () {
                      Clipboard.setData(ClipboardData(text: '@${user.username}'));
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Username copied to clipboard')),
                      );
                    },
                  ),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 24),
        // Theme Mode Preference
        Card(
          elevation: 0,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.palette_outlined),
                title: const Text('Theme Mode'),
                subtitle: Consumer<ThemeProvider>(
                  builder: (context, themeProvider, _) {
                    return Text(
                      themeProvider.isDarkMode
                          ? 'Currently using Dark Mode'
                          : 'Currently using Light Mode',
                    );
                  },
                ),
                trailing: const ThemeToggleButton(size: 48),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        // About Developer Section
        Card(
          elevation: 0,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.info_outline),
                title: const Text('About the Developer'),
                subtitle: const Text('Learn more about who created this app'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () {
                  _showDeveloperInfo(context);
                },
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        Card(
          elevation: 0,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.lock_reset),
                title: const Text('Reset password'),
                subtitle: const Text(
                  'Use the "Forgot password" option on the login screen if you need to change it.',
                ),
                onTap: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text(
                        'Open the login screen and choose "Forgot password" to start the reset flow.',
                      ),
                    ),
                  );
                },
              ),
              const Divider(height: 0),
              ListTile(
                leading: const Icon(Icons.logout),
                title: const Text('Log out'),
                onTap: provider.logout,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _TotalJuzCompleted extends StatelessWidget {
  const _TotalJuzCompleted({required this.userId});

  final String userId;

  @override
  Widget build(BuildContext context) {
    final firestore = context.read<FirestoreService>();
    return StreamBuilder<List<RecitationAssignment>>(
      stream: firestore.watchMemberAssignments(userId),
      builder: (context, snapshot) {
        final assignments = snapshot.data ?? [];
        final completedJuz = <int>{};
        int totalCompleted = 0;

        for (final assignment in assignments) {
          if (assignment.isCompleted) {
            completedJuz.add(assignment.juzNumber.toInt());
            totalCompleted++;
          }
        }

        final uniqueJuzCompleted = completedJuz.length;

        return Card(
          color: Theme.of(context).colorScheme.primaryContainer.withOpacity(0.3),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Icon(
                  Icons.menu_book,
                  color: Theme.of(context).colorScheme.primary,
                  size: 32,
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Total Completed Juz',
                        style: Theme.of(context).textTheme.titleSmall,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '$uniqueJuzCompleted unique Juz completed',
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: Theme.of(context).colorScheme.primary,
                            ),
                      ),
                      if (totalCompleted > uniqueJuzCompleted)
                        Text(
                          '$totalCompleted total assignments completed',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                    ],
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
