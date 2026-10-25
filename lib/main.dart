import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'firebase_options.dart';
import 'package:youtube_player_iframe/youtube_player_iframe.dart';
import 'package:cloud_functions/cloud_functions.dart';

const backendBaseUrl = String.fromEnvironment(
  'NEWS_API_BASE_URL',
  defaultValue: 'http://localhost:3000',
);

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    if (const bool.fromEnvironment('USE_FUNCTIONS_EMULATOR')) {
      FirebaseFunctions.instance.useFunctionsEmulator(
        const String.fromEnvironment(
          'FUNCTIONS_EMULATOR_HOST',
          defaultValue: '127.0.0.1',
        ),
        5001,
      );
    }
  } catch (e) {
    debugPrint("Firebase init error: $e");
  }

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Just The Facts',
      theme: ThemeData(scaffoldBackgroundColor: const Color(0xFF4A3B32)),
      home:
          const WelcomeScreen(), //this is the welcome screen where the user picks whether they sign in or sign up
    );
  }
}

// this is where the welcome screen design happens!!
class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key});
  @override
  Widget build(BuildContext context) {
    const lightBlueColor = Color(
      0xFFB3E5FC,
    ); // the color of the text on the homescreen

    return Scaffold(
      backgroundColor: const Color(0xFF4A3B32),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 20.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const SizedBox(height: 20),

              // the title of my app, and the photo behind it
              Stack(
                alignment: Alignment.center,
                children: [
                  Image.network(
                    'Firefly_Please remove the quick edit and next buttom 65913 (1).png', //change this
                    height: 260,
                    fit: BoxFit.contain,
                    errorBuilder: (context, error, stackTrace) {
                      return Container(
                        height: 220,
                        width: double.infinity,
                        decoration: BoxDecoration(
                          color: const Color(0xFFD2B48C),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(
                          Icons.account_balance,
                          size: 100,
                          color: Color(0xFF4A3B32),
                        ),
                      );
                    },
                  ),
                  const Text(
                    'Just The Facts',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 42,
                      fontWeight: FontWeight.w900,
                      color: lightBlueColor,
                      letterSpacing: -1.0,
                      shadows: [
                        Shadow(
                          offset: Offset(2, 2),
                          blurRadius: 4.0,
                          color: Colors.black45,
                        ),
                      ],
                    ),
                  ),
                ],
              ),

              // Light Blue Buttons
              Column(
                children: [
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) =>
                                const AuthScreen(isSignUp: false),
                          ),
                        );
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: lightBlueColor,
                        foregroundColor: const Color(0xFF2C1E16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      child: const Text(
                        'Sign In',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) =>
                                const AuthScreen(isSignUp: true),
                          ),
                        );
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: lightBlueColor,
                        foregroundColor: const Color(0xFF2C1E16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      child: const Text(
                        'Sign Up',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

//now we have to start with the google authentication service so users can actually sign in
// and sign up. this is the authentication logic... not the actual screen! (or any design features)

class SignInService {
  static Future<UserCredential?> signInWithGoogle() async {
    try {
      if (kIsWeb) {
        GoogleAuthProvider googleProvider = GoogleAuthProvider();
        return await FirebaseAuth.instance.signInWithPopup(googleProvider);
      } else {
        //note to self: i am using the googlesignin version 7.2+ which requires a specific package when trying to use GoogleSignIn instances
        final googleSignIn = GoogleSignIn.instance;
        await googleSignIn.initialize();
        final GoogleSignInAccount googleUser = await googleSignIn
            .authenticate();

        final List<String> scopes = ['email', 'profile'];
        final clientAuth = await googleUser.authorizationClient.authorizeScopes(
          scopes,
        );

        final GoogleSignInAuthentication googleAuth = googleUser.authentication;

        final OAuthCredential credential = GoogleAuthProvider.credential(
          accessToken: clientAuth.accessToken,
          idToken: googleAuth.idToken,
        );

        return await FirebaseAuth.instance.signInWithCredential(credential);
      }
    } catch (e) {
      debugPrint("Google Sign-In Error: $e");
      return null;
    }
  }

  static Future<UserCredential?> signInWithEmail(
    String email,
    String password,
  ) async {
    try {
      return await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
    } catch (e) {
      debugPrint("Email Sign In Error $e");
      return null;
    }
  }

  static Future<UserCredential?> registerWithEmail(
    String email,
    String password,
    String username,
  ) async {
    try {
      UserCredential credential = await FirebaseAuth.instance
          .createUserWithEmailAndPassword(email: email, password: password);

      await credential.user?.updateDisplayName(username);
      return credential;
    } catch (e) {
      debugPrint("Registration Error: $e");
      return null;
    }
  }
}

//authentication screen the actual design which allows the logic to be executed.

class AuthScreen extends StatefulWidget {
  final bool isSignUp;

  const AuthScreen({super.key, this.isSignUp = false});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  late bool _isSignUpMode;
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _usernameController = TextEditingController();
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _isSignUpMode = widget.isSignUp;
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _usernameController.dispose();
    super.dispose();
  }

  void _navigateToCategories() {
    if (context.mounted) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) =>
              const CategorySelectionScreen(), // if theres an error here it is because you havent put categorysleectioctionscreen as a class yet
        ),
      );
    }
  }

  Future<void> _handleAuth() async {
    setState(() => _isLoading = true);
    UserCredential? credential;

    if (_isSignUpMode) {
      credential = await SignInService.registerWithEmail(
        _emailController.text.trim(),
        _passwordController.text.trim(),
        _usernameController.text.trim(),
      );
    } else {
      credential = await SignInService.signInWithEmail(
        _emailController.text.trim(),
        _passwordController.text.trim(),
      );
    }

    setState(() => _isLoading = false);

    if (credential != null) {
      _navigateToCategories();
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Authentication failed. Please check credentials.'),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    const lightBlueColor = Color(0xFFB3E5FC);

    return Scaffold(
      backgroundColor: const Color(0xFF4A3B32),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: lightBlueColor),
      ),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _isSignUpMode ? 'Create Account' : 'Welcome Back',
                style: const TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                  color: lightBlueColor,
                ),
              ),
              const SizedBox(height: 30),

              if (_isSignUpMode) ...[
                TextField(
                  controller: _usernameController,
                  style: const TextStyle(color: Colors.white),
                  decoration: const InputDecoration(
                    labelText: 'Username',
                    labelStyle: TextStyle(color: lightBlueColor),
                    enabledBorder: OutlineInputBorder(
                      borderSide: BorderSide(color: lightBlueColor),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderSide: BorderSide(color: Colors.white),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
              ],

              TextField(
                controller: _emailController,
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(
                  labelText: 'Email',
                  labelStyle: TextStyle(color: lightBlueColor),
                  enabledBorder: OutlineInputBorder(
                    borderSide: BorderSide(color: lightBlueColor),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderSide: BorderSide(color: Colors.white),
                  ),
                ),
              ),
              const SizedBox(height: 16),

              TextField(
                controller: _passwordController,
                obscureText: true,
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(
                  labelText: 'Password',
                  labelStyle: TextStyle(color: lightBlueColor),
                  enabledBorder: OutlineInputBorder(
                    borderSide: BorderSide(color: lightBlueColor),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderSide: BorderSide(color: Colors.white),
                  ),
                ),
              ),
              const SizedBox(height: 24),

              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _handleAuth,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: lightBlueColor,
                    foregroundColor: const Color(0xFF2C1E16),
                  ),
                  child: _isLoading
                      ? const CircularProgressIndicator()
                      : Text(
                          _isSignUpMode ? 'Sign Up' : 'Sign In',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                ),
              ),
              const SizedBox(height: 16),

              TextButton(
                onPressed: () {
                  setState(() => _isSignUpMode = !_isSignUpMode);
                },
                child: Text(
                  _isSignUpMode
                      ? 'Already have an account? Sign In'
                      : "Don't have an account? Sign Up",
                  style: const TextStyle(color: lightBlueColor),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

//category selection screen where the user can select their preferred news categories after signing in or signing up.

class CategorySelectionScreen extends StatefulWidget {
  const CategorySelectionScreen({super.key});

  @override
  State<CategorySelectionScreen> createState() =>
      _CategorySelectionScreenState();
}

class _CategorySelectionScreenState extends State<CategorySelectionScreen> {
  final List<String> _politicsTopics = [
    'general geopolitics',
    'United States politics',
    'national politics',
    'Economic Politics',
    'Artificial Intelligence Politics',
    'Israelo-Palestinian Conflict Politics',
    'Russian-Ukrainian Conflict Politics',
  ];

  final Set<String> _selectedTopics = {};
  bool _isLoading = false;

  Future<void> _submitCategories() async {
    if (_selectedTopics.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select at least one topic')),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final url = Uri.parse('$backendBaseUrl/api/fetch-news');
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'userPicks': _selectedTopics.toList()}),
      );

      if (response.statusCode == 200) {
        final flatVideos = _parseNewsVideos(response.body);
        if (mounted) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => VideoFeedScreen(
                videos: flatVideos,
                userPicks: _selectedTopics.toList(),
              ),
            ),
          );
        }
        debugPrint('Fetched ${flatVideos.length} news videos');
      } else {
        debugPrint('Failed to fetch news. Status code: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('Error fetching news: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    const lightBlueColor = Color(0xFFB3E5FC);

    return Scaffold(
      backgroundColor: const Color(0xFF4A3B32),
      appBar: AppBar(
        title: const Text('Select Topics'),
        backgroundColor: const Color(0xFF4A3B32),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Expanded(
              child: ListView.builder(
                itemCount: _politicsTopics.length,
                itemBuilder: (context, index) {
                  final topic = _politicsTopics[index];
                  final isSelected = _selectedTopics.contains(topic);
                  return ListTile(
                    title: Text(
                      topic,
                      style: const TextStyle(color: Colors.white),
                    ),
                    trailing: isSelected
                        ? const Icon(Icons.check, color: lightBlueColor)
                        : null,
                    onTap: () {
                      setState(() {
                        if (isSelected) {
                          _selectedTopics.remove(topic);
                        } else {
                          _selectedTopics.add(topic);
                        }
                      });
                    },
                  );
                },
              ),
            ),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _submitCategories,
                style: ElevatedButton.styleFrom(
                  backgroundColor: lightBlueColor,
                  foregroundColor: const Color(0xFF2C1E16),
                ),
                child: _isLoading
                    ? const CircularProgressIndicator()
                    : const Text(
                        'Submit',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class NewsVideo {
  final String id;
  final String title;
  final String channelTitle;
  final String videoURL;
  final String description;
  final String publishedDate;
  final String summary;

  NewsVideo({
    required this.id,
    required this.title,
    required this.channelTitle,
    required this.videoURL,
    required this.description,
    required this.publishedDate,
    required this.summary,
  });

  factory NewsVideo.fromYouTubeJson(Map<String, dynamic> json) {
    final snippet = json['snippet'] ?? {};

    // Safely extract videoId whether 'id' is a Map or a direct String
    String videoId = '';
    final rawId = json['id'];
    if (rawId is Map) {
      videoId = rawId['videoId'] ?? rawId['id'] ?? '';
    } else if (rawId is String) {
      videoId = rawId;
    } else if (json['videoId'] != null) {
      videoId = json['videoId'].toString();
    }

    return NewsVideo(
      id: videoId,
      title: _cleanVideoTitle(
        (snippet['title'] ?? json['title'] ?? 'Untitled News').toString(),
      ),
      channelTitle:
          snippet['channelTitle'] ?? json['channelTitle'] ?? 'News Channel',
      videoURL: 'https://www.youtube.com/watch?v=$videoId',
      description:
          snippet['description'] ??
          json['description'] ??
          'No description available.',
      publishedDate:
          snippet['publishedAt'] ?? json['publishedAt'] ?? 'Unknown date',
      summary: json['summary'] ?? '',
    );
  }
}

String _cleanVideoTitle(String title) {
  const namedEntities = {
    'amp': '&',
    'apos': "'",
    'gt': '>',
    'lt': '<',
    'nbsp': ' ',
    'quot': '"',
  };
  final entityPattern = RegExp(
    r'&(#(?:x[0-9a-fA-F]+|[0-9]+)|[a-zA-Z][a-zA-Z0-9]+);?',
  );

  var cleanedTitle = title;
  for (var pass = 0; pass < 3; pass++) {
    final decodedTitle = cleanedTitle.replaceAllMapped(entityPattern, (match) {
      final entity = match[1]!;
      if (entity.startsWith('#')) {
        final isHex = entity.startsWith('#x') || entity.startsWith('#X');
        final digits = entity.substring(isHex ? 2 : 1);
        final codePoint = int.tryParse(digits, radix: isHex ? 16 : 10);
        if (codePoint == null ||
            codePoint <= 0 ||
            codePoint > 0x10FFFF ||
            (codePoint >= 0xD800 && codePoint <= 0xDFFF)) {
          return match[0]!;
        }
        return String.fromCharCode(codePoint);
      }
      return namedEntities[entity] ?? match[0]!;
    });
    if (decodedTitle == cleanedTitle) break;
    cleanedTitle = decodedTitle;
  }
  return cleanedTitle.trim();
}

List<NewsVideo> _parseNewsVideos(String responseBody) {
  final decoded = jsonDecode(responseBody);
  if (decoded is! Map<String, dynamic>) {
    throw const FormatException(
      'The news service returned an invalid response.',
    );
  }

  final groups = decoded['data'];
  if (groups is! List) return [];

  final videos = <NewsVideo>[];
  for (final group in groups) {
    if (group is! Map || group['videos'] is! List) continue;
    for (final item in group['videos'] as List) {
      if (item is! Map<String, dynamic>) continue;
      final video = NewsVideo.fromYouTubeJson(item);
      if (video.id.isNotEmpty) videos.add(video);
    }
  }
  return videos;
}

// this is the video feed screen that will display the videos in a vertical scrollable list. it takes a list of NewsVideo objects as a parameter and uses a PageView.builder to create a vertical scrollable list of VideoPlayerItem widgets. if the list is empty, it displays a message saying that there are no videos available right now.
class VideoFeedScreen extends StatefulWidget {
  final List<NewsVideo> videos;
  final List<String> userPicks;

  const VideoFeedScreen({
    super.key,
    required this.videos,
    this.userPicks = const [],
  });

  @override
  State<VideoFeedScreen> createState() => _VideoFeedScreenState();
}

class _VideoFeedScreenState extends State<VideoFeedScreen> {
  late final PageController _pageController;
  late List<NewsVideo> _videos;
  int _currentPage = 0;
  int _selectedTab = 0;
  bool _isRefreshing = false;
  bool _isUploadingProfilePhoto = false;
  String? _profilePhotoUrl;

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
    _videos = List.of(widget.videos);
    _profilePhotoUrl = FirebaseAuth.instance.currentUser?.photoURL;
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _goToPage(int page) {
    if (page < 0 || page >= _videos.length) return;

    _pageController.animateToPage(
      page,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
  }

  void _selectTab(int tab) {
    if (tab == 0) {
      setState(() => _selectedTab = 0);
      _refreshFeed();
      return;
    }
    setState(() => _selectedTab = tab);
  }

  Future<void> _refreshFeed() async {
    if (_isRefreshing) return;
    if (widget.userPicks.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Choose news topics before refreshing the feed.'),
        ),
      );
      return;
    }

    setState(() => _isRefreshing = true);
    try {
      final response = await http.post(
        Uri.parse('$backendBaseUrl/api/fetch-news'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'userPicks': widget.userPicks}),
      );

      if (response.statusCode != 200) {
        debugPrint(
          'Failed to refresh news. Status code: ${response.statusCode}',
        );
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Could not refresh the video feed.')),
          );
        }
        return;
      }

      final videos = _parseNewsVideos(response.body);
      if (videos.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'No videos are available right now. Try again later.',
              ),
            ),
          );
        }
        return;
      }

      if (!mounted) return;
      if (_pageController.hasClients) _pageController.jumpToPage(0);
      setState(() {
        _videos = videos;
        _currentPage = 0;
      });
    } catch (error) {
      debugPrint('Error refreshing news feed: $error');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not refresh the video feed.')),
        );
      }
    } finally {
      if (mounted) setState(() => _isRefreshing = false);
    }
  }

  Widget _buildArrowButton({
    required IconData icon,
    required String tooltip,
    required VoidCallback? onPressed,
    double size = 48,
  }) {
    return IconButton(
      tooltip: tooltip,
      onPressed: onPressed,
      icon: Icon(icon),
      style: IconButton.styleFrom(
        backgroundColor: const Color(0xFFE91E63),
        foregroundColor: Colors.white,
        disabledBackgroundColor: Colors.white24,
        disabledForegroundColor: Colors.white54,
        fixedSize: Size.square(size),
        shape: const CircleBorder(),
      ),
    );
  }

  Widget _buildNavigationButton({
    required IconData icon,
    required String tooltip,
    required int tab,
  }) {
    final isSelected = _selectedTab == tab;
    return IconButton(
      tooltip: tooltip,
      onPressed: () => _selectTab(tab),
      icon: tab == 0 && _isRefreshing
          ? const SizedBox.square(
              dimension: 22,
              child: CircularProgressIndicator(
                color: Colors.white,
                strokeWidth: 2,
              ),
            )
          : Icon(icon, size: 28),
      style: IconButton.styleFrom(
        foregroundColor: Colors.white,
        backgroundColor: isSelected
            ? const Color(0xFF292D32)
            : Colors.transparent,
        fixedSize: const Size.square(52),
        shape: const CircleBorder(),
      ),
    );
  }

  Widget _buildNavigationBar({required bool isDesktop}) {
    const backgroundColor = Color(0xFF0B0F12);
    if (isDesktop) {
      return Container(
        width: 76,
        color: backgroundColor,
        child: SafeArea(
          child: Column(
            children: [
              const SizedBox(height: 28),
              _buildNavigationButton(
                icon: Icons.smart_display_outlined,
                tooltip: 'Video feed',
                tab: 0,
              ),
              const Spacer(),
              _buildNavigationButton(
                icon: Icons.account_circle_outlined,
                tooltip: 'Profile',
                tab: 1,
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      );
    }

    return Container(
      color: backgroundColor,
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 64,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _buildNavigationButton(
                icon: Icons.smart_display_outlined,
                tooltip: 'Video feed',
                tab: 0,
              ),
              _buildNavigationButton(
                icon: Icons.account_circle_outlined,
                tooltip: 'Profile',
                tab: 1,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _pickProfilePhoto() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      _showProfileMessage('Sign in to update your profile photo.');
      return;
    }

    try {
      final image = await ImagePicker().pickImage(
        source: ImageSource.gallery,
        imageQuality: 85,
      );
      if (image == null || !mounted) return;

      setState(() => _isUploadingProfilePhoto = true);
      final metadata = SettableMetadata(
        contentType: image.mimeType ?? 'image/jpeg',
      );
      final avatarRef = FirebaseStorage.instance.ref(
        'users/${user.uid}/avatar',
      );
      await avatarRef.putData(await image.readAsBytes(), metadata);
      final photoUrl = await avatarRef.getDownloadURL();
      await user.updatePhotoURL(photoUrl);
      await user.reload();

      if (!mounted) return;
      setState(() {
        _profilePhotoUrl = photoUrl;
        _isUploadingProfilePhoto = false;
      });
      _showProfileMessage('Profile photo updated.');
    } catch (error) {
      debugPrint('Error updating profile photo: $error');
      if (!mounted) return;
      setState(() => _isUploadingProfilePhoto = false);
      _showProfileMessage('Could not update your profile photo.');
    }
  }

  Future<void> _editBio(String currentBio) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      _showProfileMessage('Sign in to edit your profile.');
      return;
    }

    final controller = TextEditingController(text: currentBio);
    final bio = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: const Color(0xFF202428),
        title: const Text(
          'Edit bio or tagline',
          style: TextStyle(color: Colors.white),
        ),
        content: TextField(
          controller: controller,
          autofocus: true,
          maxLength: 160,
          maxLines: 3,
          style: const TextStyle(color: Colors.white),
          decoration: const InputDecoration(
            hintText: 'Tell people a little about yourself',
            hintStyle: TextStyle(color: Colors.white54),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, controller.text),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (bio == null) return;

    try {
      await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
        'bio': bio.trim(),
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      if (mounted) _showProfileMessage('Profile bio updated.');
    } catch (error) {
      debugPrint('Error saving profile bio: $error');
      if (mounted) _showProfileMessage('Could not save your profile bio.');
    }
  }

  Future<void> _editUsername(String currentUsername) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      _showProfileMessage('Sign in to change your username.');
      return;
    }

    final controller = TextEditingController(text: currentUsername);
    final username = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: const Color(0xFF202428),
        title: const Text(
          'Change username',
          style: TextStyle(color: Colors.white),
        ),
        content: TextField(
          controller: controller,
          autofocus: true,
          maxLength: 50,
          textCapitalization: TextCapitalization.words,
          style: const TextStyle(color: Colors.white),
          decoration: const InputDecoration(
            labelText: 'Username',
            labelStyle: TextStyle(color: Colors.white70),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, controller.text),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (username == null) return;

    final trimmedUsername = username.trim();
    if (trimmedUsername.isEmpty) {
      _showProfileMessage('Username cannot be empty.');
      return;
    }

    try {
      await user.updateDisplayName(trimmedUsername);
      await user.reload();
      if (!mounted) return;
      setState(() {});
      _showProfileMessage('Username updated.');
    } catch (error) {
      debugPrint('Error updating username: $error');
      if (mounted) _showProfileMessage('Could not update your username.');
    }
  }

  Future<void> _removeSavedVideo(String videoId) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      _showProfileMessage('Sign in to manage saved videos.');
      return;
    }

    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('savedVideos')
          .doc(videoId)
          .delete();
      if (mounted) _showProfileMessage('Video removed from saved videos.');
    } catch (error) {
      debugPrint('Error removing saved video: $error');
      if (mounted) _showProfileMessage('Could not remove the saved video.');
    }
  }

  void _openSavedVideo(QueryDocumentSnapshot<Map<String, dynamic>> savedVideo) {
    final data = savedVideo.data();
    final video = NewsVideo(
      id: data['videoId'] as String? ?? savedVideo.id,
      title: _cleanVideoTitle(data['title'] as String? ?? 'Saved video'),
      channelTitle: data['channelTitle'] as String? ?? 'News Channel',
      videoURL:
          data['videoURL'] as String? ??
          'https://www.youtube.com/watch?v=${savedVideo.id}',
      description: data['description'] as String? ?? '',
      publishedDate: data['publishedDate'] as String? ?? 'Unknown date',
      summary: data['summary'] as String? ?? '',
    );
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (context) => SavedVideoPlayerScreen(video: video),
      ),
    );
  }

  void _showProfileMessage(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  Widget _buildProfile() {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return const ColoredBox(
        color: Color(0xFF0B0F12),
        child: Center(
          child: Text(
            'Sign in to view your profile.',
            style: TextStyle(color: Colors.white70),
          ),
        ),
      );
    }

    final profileRef = FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid);

    return ColoredBox(
      color: const Color(0xFF0B0F12),
      child: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        stream: profileRef.snapshots(),
        builder: (context, profileSnapshot) {
          final profile = profileSnapshot.data?.data();
          final bio = profile?['bio'] as String? ?? '';
          final email = user.email;

          return Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 760),
              child: ListView(
                padding: const EdgeInsets.all(24),
                children: [
                  if (profileSnapshot.hasError)
                    const Padding(
                      padding: EdgeInsets.only(bottom: 16),
                      child: Text(
                        'Could not load your profile details. Check your '
                        'Firebase rules and connection.',
                        style: TextStyle(color: Colors.orangeAccent),
                      ),
                    ),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Stack(
                        children: [
                          CircleAvatar(
                            radius: 48,
                            backgroundColor: const Color(0xFF292D32),
                            backgroundImage: _profilePhotoUrl == null
                                ? null
                                : NetworkImage(_profilePhotoUrl!),
                            child: _profilePhotoUrl == null
                                ? const Icon(
                                    Icons.account_circle_outlined,
                                    color: Colors.white,
                                    size: 56,
                                  )
                                : null,
                          ),
                          Positioned(
                            right: 0,
                            bottom: 0,
                            child: IconButton(
                              tooltip: 'Change profile photo',
                              onPressed: _isUploadingProfilePhoto
                                  ? null
                                  : _pickProfilePhoto,
                              icon: _isUploadingProfilePhoto
                                  ? const SizedBox.square(
                                      dimension: 20,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                      ),
                                    )
                                  : const Icon(Icons.camera_alt),
                              style: IconButton.styleFrom(
                                backgroundColor: const Color(0xFFE91E63),
                                foregroundColor: Colors.white,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(width: 20),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              user.displayName?.isNotEmpty == true
                                  ? user.displayName!
                                  : 'Your profile',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 22,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            if (email?.isNotEmpty == true) ...[
                              const SizedBox(height: 4),
                              Text(
                                email!,
                                style: const TextStyle(color: Colors.white70),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  Text(
                    bio.isEmpty ? 'Add a bio or tagline' : bio,
                    style: TextStyle(
                      color: bio.isEmpty ? Colors.white54 : Colors.white,
                      fontSize: 15,
                    ),
                  ),
                  const SizedBox(height: 16),
                  OutlinedButton.icon(
                    onPressed: () => _editBio(bio),
                    icon: const Icon(Icons.edit_outlined),
                    label: const Text('Edit bio or tagline'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.white,
                      side: const BorderSide(color: Colors.white24),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                  ),
                  const SizedBox(height: 10),
                  OutlinedButton.icon(
                    onPressed: () => _editUsername(
                      user.displayName?.trim().isNotEmpty == true
                          ? user.displayName!.trim()
                          : '',
                    ),
                    icon: const Icon(Icons.person_outline),
                    label: const Text('Change username'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.white,
                      side: const BorderSide(color: Colors.white24),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                  ),
                  const SizedBox(height: 32),
                  const Divider(color: Colors.white24),
                  const SizedBox(height: 12),
                  const Row(
                    children: [
                      Icon(Icons.bookmark_outline, color: Colors.white),
                      SizedBox(width: 10),
                      Text(
                        'Saved videos',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Spacer(),
                      Text(
                        'Only you can see these',
                        style: TextStyle(color: Colors.white54, fontSize: 12),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                    stream: profileRef
                        .collection('savedVideos')
                        .orderBy('savedAt', descending: true)
                        .snapshots(),
                    builder: (context, savedSnapshot) {
                      if (savedSnapshot.hasError) {
                        debugPrint(
                          'Error loading saved videos: '
                          '${savedSnapshot.error}',
                        );
                        return const Padding(
                          padding: EdgeInsets.symmetric(vertical: 16),
                          child: Text(
                            'Could not load saved videos.',
                            style: TextStyle(color: Colors.white70),
                          ),
                        );
                      }
                      if (savedSnapshot.connectionState ==
                              ConnectionState.waiting &&
                          !savedSnapshot.hasData) {
                        return const Center(
                          child: Padding(
                            padding: EdgeInsets.all(20),
                            child: CircularProgressIndicator(),
                          ),
                        );
                      }

                      final savedVideos = savedSnapshot.data?.docs ?? [];
                      if (savedVideos.isEmpty) {
                        return const Padding(
                          padding: EdgeInsets.symmetric(vertical: 16),
                          child: Text(
                            'Videos you save from the feed will appear here.',
                            style: TextStyle(color: Colors.white70),
                          ),
                        );
                      }

                      return Column(
                        children: [
                          for (final savedVideo in savedVideos)
                            ListTile(
                              contentPadding: const EdgeInsets.symmetric(
                                vertical: 4,
                              ),
                              onTap: () => _openSavedVideo(savedVideo),
                              leading: ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child: Stack(
                                  alignment: Alignment.center,
                                  children: [
                                    Image.network(
                                      'https://img.youtube.com/vi/${savedVideo.data()['videoId'] as String? ?? savedVideo.id}/hqdefault.jpg',
                                      width: 120,
                                      height: 68,
                                      fit: BoxFit.cover,
                                      errorBuilder:
                                          (context, error, stackTrace) =>
                                              const SizedBox(
                                                width: 120,
                                                height: 68,
                                                child: ColoredBox(
                                                  color: Colors.black26,
                                                  child: Icon(
                                                    Icons.play_circle_outline,
                                                    color: Colors.white70,
                                                  ),
                                                ),
                                              ),
                                    ),
                                    const Icon(
                                      Icons.play_circle_fill,
                                      color: Colors.white,
                                      size: 30,
                                    ),
                                  ],
                                ),
                              ),
                              title: Text(
                                _cleanVideoTitle(
                                  savedVideo.data()['title'] as String? ??
                                      'Saved video',
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(color: Colors.white),
                              ),
                              subtitle: Text(
                                savedVideo.data()['channelTitle'] as String? ??
                                    '',
                                style: const TextStyle(color: Colors.white60),
                              ),
                              trailing: IconButton(
                                tooltip: 'Remove saved video',
                                onPressed: () =>
                                    _removeSavedVideo(savedVideo.id),
                                icon: const Icon(
                                  Icons.bookmark,
                                  color: Color(0xFFE91E63),
                                ),
                              ),
                            ),
                        ],
                      );
                    },
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildSelectedPage() {
    return _selectedTab == 0 ? _buildFeed() : _buildProfile();
  }

  Widget _buildFeed() {
    if (_videos.isEmpty) {
      return const Center(
        child: Text(
          'No videos available right now.',
          style: TextStyle(color: Colors.white70, fontSize: 16),
        ),
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final hasMoreVideos = _currentPage < _videos.length - 1;
        final showDesktopControls = MediaQuery.sizeOf(context).width >= 700;

        return Stack(
          fit: StackFit.expand,
          children: [
            PageView.builder(
              controller: _pageController,
              scrollDirection: Axis.vertical,
              itemCount: _videos.length,
              onPageChanged: (index) {
                setState(() => _currentPage = index);
              },
              itemBuilder: (context, index) {
                return VideoPlayerItem(
                  key: ValueKey(_videos[index].id),
                  newsVideo: _videos[index],
                );
              },
            ),
            if (hasMoreVideos && _currentPage == 0)
              Positioned(
                bottom: 24,
                left: 0,
                right: 0,
                child: Center(
                  child: _buildArrowButton(
                    icon: Icons.arrow_downward,
                    tooltip: 'Scroll to the next video',
                    onPressed: () => _goToPage(_currentPage + 1),
                    size: 56,
                  ),
                ),
              ),
            if (showDesktopControls && _videos.length > 1)
              Positioned(
                right: 16,
                top: 0,
                bottom: 0,
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _buildArrowButton(
                        icon: Icons.arrow_upward,
                        tooltip: 'Previous video',
                        onPressed: _currentPage > 0
                            ? () => _goToPage(_currentPage - 1)
                            : null,
                      ),
                      const SizedBox(height: 12),
                      _buildArrowButton(
                        icon: Icons.arrow_downward,
                        tooltip: 'Next video',
                        onPressed: hasMoreVideos
                            ? () => _goToPage(_currentPage + 1)
                            : null,
                      ),
                    ],
                  ),
                ),
              ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isDesktop = constraints.maxWidth >= 700;
        return Scaffold(
          backgroundColor: Colors.black,
          body: isDesktop
              ? Row(
                  children: [
                    _buildNavigationBar(isDesktop: true),
                    Expanded(child: _buildSelectedPage()),
                  ],
                )
              : _buildSelectedPage(),
          bottomNavigationBar: isDesktop
              ? null
              : _buildNavigationBar(isDesktop: false),
        );
      },
    );
  }
}

class SavedVideoPlayerScreen extends StatefulWidget {
  final NewsVideo video;

  const SavedVideoPlayerScreen({super.key, required this.video});

  @override
  State<SavedVideoPlayerScreen> createState() => _SavedVideoPlayerScreenState();
}

class _SavedVideoPlayerScreenState extends State<SavedVideoPlayerScreen> {
  late final YoutubePlayerController _controller;

  @override
  void initState() {
    super.initState();
    _controller = YoutubePlayerController.fromVideoId(
      videoId: widget.video.id,
      autoPlay: true,
      params: const YoutubePlayerParams(
        showControls: true,
        showFullscreenButton: true,
        mute: false,
      ),
    );
  }

  @override
  void dispose() {
    _controller.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: const Text('Saved video'),
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                AspectRatio(
                  aspectRatio: 16 / 9,
                  child: YoutubePlayer(controller: _controller),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.video.title,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        widget.video.channelTitle,
                        style: const TextStyle(color: Colors.white70),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// this is the video player widget that will be used to display the videos in the newsfeed screen. it uses the youtube_player_iframe package to play the videos. it takes a NewsVideo object as a parameter and uses its id to create a YoutubePlayerController. it also has a dispose method to close the controller when the widget is disposed of.
// this is the design part of the video player widget.
class VideoPlayerItem extends StatefulWidget {
  final NewsVideo newsVideo;

  const VideoPlayerItem({super.key, required this.newsVideo});

  @override
  State<VideoPlayerItem> createState() => _VideoPlayerItemState();
}

class _VideoPlayerItemState extends State<VideoPlayerItem> {
  late final YoutubePlayerController _controller;
  bool _isSaved = false;
  bool _isSavingVideo = false;
  bool _isLoadingSavedState = true;

  @override
  void initState() {
    super.initState();
    _controller = YoutubePlayerController.fromVideoId(
      videoId: widget.newsVideo.id,
      autoPlay: false,
      params: const YoutubePlayerParams(
        showControls: true,
        showFullscreenButton: true,
        mute: false,
      ),
    );
    _loadSavedState();
  }

  @override
  void dispose() {
    _controller.close();
    super.dispose();
  }

  Future<void> _loadSavedState() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      if (mounted) setState(() => _isLoadingSavedState = false);
      return;
    }

    try {
      final savedVideo = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('savedVideos')
          .doc(widget.newsVideo.id)
          .get();
      if (mounted) setState(() => _isSaved = savedVideo.exists);
    } on FirebaseException catch (error) {
      debugPrint(
        'Error checking saved video [${error.code}]: ${error.message}',
      );
    } catch (error) {
      debugPrint('Error checking saved video: $error');
    } finally {
      if (mounted) setState(() => _isLoadingSavedState = false);
    }
  }

  Future<void> _toggleSavedVideo() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Sign in to save videos.')));
      return;
    }
    if (_isSavingVideo || _isLoadingSavedState) return;

    setState(() => _isSavingVideo = true);
    final savedVideoRef = FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .collection('savedVideos')
        .doc(widget.newsVideo.id);

    try {
      if (_isSaved) {
        await savedVideoRef.delete();
      } else {
        await savedVideoRef.set({
          'videoId': widget.newsVideo.id,
          'title': widget.newsVideo.title,
          'channelTitle': widget.newsVideo.channelTitle,
          'videoURL': widget.newsVideo.videoURL,
          'description': widget.newsVideo.description,
          'publishedDate': widget.newsVideo.publishedDate,
          'summary': widget.newsVideo.summary,
          'savedAt': FieldValue.serverTimestamp(),
        });
      }
      if (!mounted) return;
      setState(() => _isSaved = !_isSaved);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _isSaved ? 'Video saved to your profile.' : 'Video unsaved.',
          ),
        ),
      );
    } on FirebaseException catch (error) {
      debugPrint('Error saving video [${error.code}]: ${error.message}');
      if (mounted) {
        final message = error.code == 'permission-denied'
            ? 'Firestore denied this save. Deploy the project Firestore rules '
                  'with: firebase deploy --only firestore:rules'
            : 'Could not update saved videos (${error.code}).';
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(message)));
      }
    } catch (error) {
      debugPrint('Error saving video: $error');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not update saved videos.')),
        );
      }
    } finally {
      if (mounted) setState(() => _isSavingVideo = false);
    }
  }
  //the AI overview part of the like button that will show the AI summary of the video in a modal bottom sheet. it uses the showModalBottomSheet function to display the summary. it takes a BuildContext as a parameter and uses the widget.newsVideo.summary to display the summary. if the summary is empty, it displays a message saying that there is no summary available for this video yet.

  void _showComments() {
    if (FirebaseAuth.instance.currentUser == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Sign in to view comments.')),
      );
      return;
    }

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF111518),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => _VideoCommentsSheet(video: widget.newsVideo),
    );
  }

  Future<String> _generateAiOverview() async {
    final request = {
      'title': widget.newsVideo.title,
      'content': widget.newsVideo.description,
      'publishedDate': widget.newsVideo.publishedDate,
      'videoUrl': widget.newsVideo.videoURL,
    };

    http.Response? response;
    try {
      response = await http
          .post(
            Uri.parse('$backendBaseUrl/api/generate-ai-summary'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode(request),
          )
          .timeout(const Duration(seconds: 30));
    } catch (error) {
      debugPrint('Primary AI overview service failed; trying Firebase: $error');
    }

    if (response != null) {
      if (response.statusCode == 200) {
        try {
          final data = jsonDecode(response.body) as Map<String, dynamic>;
          final summary = data['summary'];
          if (summary is String && summary.trim().isNotEmpty) {
            return summary;
          }
          debugPrint(
            'Primary AI overview returned no summary; trying Firebase.',
          );
        } catch (error) {
          debugPrint(
            'Primary AI overview response was invalid; trying Firebase: $error',
          );
        }
      } else {
        debugPrint(
          'Primary AI overview service returned ${response.statusCode}; '
          'trying Firebase fallback.',
        );
      }
    }

    final callable = FirebaseFunctions.instance.httpsCallable(
      'generateAiSummary',
    );
    final result = await callable.call(request);
    final data = Map<String, dynamic>.from(result.data as Map);
    final summary = data['summary'];

    if (summary is! String || summary.isEmpty) {
      throw StateError('The Firebase function returned no summary.');
    }

    return summary;
  }

  // showing the actual ai overview
  Future<void> _showAiOverview(BuildContext context) async {
    try {
      final summary = await _generateAiOverview();

      if (!context.mounted) return;
      showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.white,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        builder: (context) {
          return Container(
            padding: const EdgeInsets.all(20.0),
            constraints: BoxConstraints(
              maxHeight:
                  MediaQuery.of(context).size.height *
                  0.75, // Fixed missing '*' and removed '-'
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: const [
                    Icon(Icons.favorite, color: Colors.purple),
                    SizedBox(width: 8),
                    Text(
                      'AI Video Breakdown',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.black,
                      ),
                    ),
                  ],
                ),
                const Divider(height: 24),
                Expanded(
                  child: SingleChildScrollView(
                    child: Text(
                      summary,
                      style: const TextStyle(
                        fontSize: 15,
                        height: 1.5,
                        color: Colors.black87,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      );
    } catch (error) {
      debugPrint('Error generating AI overview: $error');
      if (!context.mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not generate overview.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.black,
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 16.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.newsVideo.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      widget.newsVideo.channelTitle,
                      style: const TextStyle(
                        color: Color(0xFFB3E5FC),
                        fontWeight: FontWeight.w600,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Column(
                children: [
                  IconButton(
                    onPressed: () => _showAiOverview(context),
                    icon: const Icon(
                      Icons.auto_awesome,
                      color: Color(0xFFB3E5FC),
                      size: 28,
                    ),
                  ),
                  const Text(
                    'AI Overview',
                    style: TextStyle(
                      color: Color(0xFFB3E5FC),
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 12),
                  IconButton(
                    tooltip: 'View comments',
                    onPressed: _showComments,
                    icon: const Icon(
                      Icons.chat_bubble_outline,
                      color: Color(0xFFB3E5FC),
                      size: 28,
                    ),
                  ),
                  const Text(
                    'Comments',
                    style: TextStyle(
                      color: Color(0xFFB3E5FC),
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 12),
                  IconButton(
                    tooltip: _isSaved ? 'Remove saved video' : 'Save video',
                    onPressed: _isSavingVideo || _isLoadingSavedState
                        ? null
                        : _toggleSavedVideo,
                    icon: _isSavingVideo || _isLoadingSavedState
                        ? const SizedBox.square(
                            dimension: 22,
                            child: CircularProgressIndicator(
                              color: Color(0xFFB3E5FC),
                              strokeWidth: 2,
                            ),
                          )
                        : Icon(
                            _isSaved ? Icons.bookmark : Icons.bookmark_border,
                            color: const Color(0xFFB3E5FC),
                            size: 28,
                          ),
                  ),
                  Text(
                    _isSaved ? 'Saved' : 'Save',
                    style: const TextStyle(
                      color: Color(0xFFB3E5FC),
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),
          Expanded(
            child: Center(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: AspectRatio(
                  aspectRatio: 9 / 16,
                  child: YoutubePlayer(controller: _controller),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _VideoCommentsSheet extends StatefulWidget {
  final NewsVideo video;

  const _VideoCommentsSheet({required this.video});

  @override
  State<_VideoCommentsSheet> createState() => _VideoCommentsSheetState();
}

class _VideoCommentsSheetState extends State<_VideoCommentsSheet> {
  final TextEditingController _commentController = TextEditingController();
  bool _isPosting = false;

  CollectionReference<Map<String, dynamic>> get _comments => FirebaseFirestore
      .instance
      .collection('videos')
      .doc(widget.video.id)
      .collection('comments');

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  Future<void> _postComment() async {
    final user = FirebaseAuth.instance.currentUser;
    final text = _commentController.text.trim();
    if (user == null || text.isEmpty || _isPosting) return;
    if (text.length > 1000) {
      _showMessage('Comments must be 1,000 characters or fewer.');
      return;
    }

    setState(() => _isPosting = true);
    try {
      await _comments.add({
        'uid': user.uid,
        'authorName': user.displayName?.trim().isNotEmpty == true
            ? user.displayName!.trim()
            : user.email?.split('@').first ?? 'User',
        'text': text,
        'createdAt': FieldValue.serverTimestamp(),
      });
      _commentController.clear();
    } on FirebaseException catch (error) {
      debugPrint('Error posting comment [${error.code}]: ${error.message}');
      if (mounted) {
        final message = error.code == 'permission-denied'
            ? 'Comment was denied. Deploy Firestore rules with: '
                  'firebase deploy --only firestore:rules'
            : 'Could not post comment (${error.code}).';
        _showMessage(message);
      }
    } catch (error) {
      debugPrint('Error posting comment: $error');
      if (mounted) _showMessage('Could not post comment.');
    } finally {
      if (mounted) setState(() => _isPosting = false);
    }
  }

  Future<void> _deleteComment(String commentId) async {
    try {
      await _comments.doc(commentId).delete();
    } on FirebaseException catch (error) {
      debugPrint('Error deleting comment [${error.code}]: ${error.message}');
      if (mounted) _showMessage('Could not delete comment (${error.code}).');
    } catch (error) {
      debugPrint('Error deleting comment: $error');
      if (mounted) _showMessage('Could not delete comment.');
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final currentUserId = FirebaseAuth.instance.currentUser?.uid;
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;

    return SafeArea(
      top: false,
      child: SizedBox(
        height: MediaQuery.sizeOf(context).height * 0.75,
        child: Padding(
          padding: EdgeInsets.only(bottom: bottomInset),
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 18, 12, 12),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Comments · ${widget.video.title}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 17,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    IconButton(
                      tooltip: 'Close comments',
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.close, color: Colors.white70),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1, color: Colors.white24),
              Expanded(
                child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                  stream: _comments.orderBy('createdAt').snapshots(),
                  builder: (context, snapshot) {
                    if (snapshot.hasError) {
                      debugPrint('Error loading comments: ${snapshot.error}');
                      return const Center(
                        child: Text(
                          'Could not load comments. Check your connection '
                          'and Firebase rules.',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Colors.white70),
                        ),
                      );
                    }
                    if (!snapshot.hasData) {
                      return const Center(child: CircularProgressIndicator());
                    }

                    final comments = snapshot.data!.docs;
                    if (comments.isEmpty) {
                      return const Center(
                        child: Text(
                          'No comments yet. Start the conversation.',
                          style: TextStyle(color: Colors.white70),
                        ),
                      );
                    }

                    return ListView.builder(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      itemCount: comments.length,
                      itemBuilder: (context, index) {
                        final comment = comments[index];
                        final data = comment.data();
                        final authorName =
                            data['authorName'] as String? ?? 'User';
                        final text = data['text'] as String? ?? '';
                        final isOwnComment = data['uid'] == currentUserId;
                        final timestamp = data['createdAt'];
                        final dateLabel = timestamp is Timestamp
                            ? MaterialLocalizations.of(
                                context,
                              ).formatShortDate(timestamp.toDate())
                            : '';

                        return ListTile(
                          title: Text(
                            authorName,
                            style: const TextStyle(
                              color: Color(0xFFB3E5FC),
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                            ),
                          ),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const SizedBox(height: 4),
                              Text(
                                text,
                                style: const TextStyle(color: Colors.white),
                              ),
                              if (dateLabel.isNotEmpty) ...[
                                const SizedBox(height: 4),
                                Text(
                                  dateLabel,
                                  style: const TextStyle(
                                    color: Colors.white54,
                                    fontSize: 11,
                                  ),
                                ),
                              ],
                            ],
                          ),
                          trailing: isOwnComment
                              ? IconButton(
                                  tooltip: 'Delete your comment',
                                  onPressed: () => _deleteComment(comment.id),
                                  icon: const Icon(
                                    Icons.delete_outline,
                                    color: Colors.white54,
                                  ),
                                )
                              : null,
                        );
                      },
                    );
                  },
                ),
              ),
              const Divider(height: 1, color: Colors.white24),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 10, 12, 12),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _commentController,
                        minLines: 1,
                        maxLines: 4,
                        maxLength: 1000,
                        style: const TextStyle(color: Colors.white),
                        decoration: InputDecoration(
                          hintText: 'Add a comment...',
                          hintStyle: const TextStyle(color: Colors.white54),
                          counterText: '',
                          filled: true,
                          fillColor: const Color(0xFF202428),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 10,
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(22),
                            borderSide: BorderSide.none,
                          ),
                        ),
                        onSubmitted: (_) => _postComment(),
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      tooltip: 'Post comment',
                      onPressed: _isPosting ? null : _postComment,
                      icon: _isPosting
                          ? const SizedBox.square(
                              dimension: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.send_rounded),
                      color: const Color(0xFFB3E5FC),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// everything above this line WORKS!

//now i need to take the videos retyrned by my backend and convert them into
//NewsVideo objects so that i can display them in the newsfeed screen.
//the first thing i need to do is create an empty list that can hold the objects
// flat means the results from multiple topic groups will be collected into one list
// when i say i need to flatten them i just need to put them all in one list so that i can display them in the newsfeed screen.
//for var ground does that
//if item is Map<String, dynamic> loops through each result and creates a NewsVideo object from it, then adds it to the list.
// if video.id is not null, it adds the video to the list. if it is null, it skips that video and moves on to the next one. this is important because some videos may not have an id and we dont want to crash the app because of that.
//lets do this!
//update: i ended up moving the flattening logic into the _submitCategories function above so that i can use it immediately after fetching the news articles. this way i can display them in the newsfeed screen without having to wait for another function to be called.
// it is right under the final List<dynamic> topicResults = decoded['data'] ?? []; line.
