import 'dart:convert';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../constants/api_config.dart';
import '../services/api_service.dart';

class ApiFormWidget extends StatefulWidget {
  const ApiFormWidget({
    super.key,
    this.embedded = false,
    this.baseUrl,
    ApiService? apiService,
  }) : _apiService = apiService;

  final bool embedded;
  final String? baseUrl;
  final ApiService? _apiService;

  @override
  State<ApiFormWidget> createState() => _ApiFormWidgetState();
}

class _ApiFormWidgetState extends State<ApiFormWidget> {
  late final ApiService _apiService;

  PlatformFile? _imageFile;
  PlatformFile? _audioFile;

  final _auController = TextEditingController();
  final _cuController = TextEditingController();
  final _feController = TextEditingController();
  final _sController = TextEditingController();
  final _oController = TextEditingController();

  final _sampleIdController = TextEditingController();
  final _siteController = TextEditingController();
  final _mineralController = TextEditingController();

  bool _isLoading = false;
  String _responseText = '';

  @override
  void initState() {
    super.initState();
    _apiService = widget._apiService ?? ApiService(
      baseUrl: widget.baseUrl ?? ApiConfig.defaultBaseUrl,
    );
  }

  @override
  void dispose() {
    _auController.dispose();
    _cuController.dispose();
    _feController.dispose();
    _sController.dispose();
    _oController.dispose();
    _sampleIdController.dispose();
    _siteController.dispose();
    _mineralController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.image,
      allowMultiple: false,
    );

    if (result == null || result.files.isEmpty) {
      return;
    }

    setState(() {
      _imageFile = result.files.single;
    });
  }

  Future<void> _pickAudio() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['wav'],
      allowMultiple: false,
    );

    if (result == null || result.files.isEmpty) {
      return;
    }

    setState(() {
      _audioFile = result.files.single;
    });
  }

  Future<void> _submitPredict() async {
    final inputs = _validateCommonInputs();
    if (inputs == null) {
      return;
    }

    await _sendRequest(
      () => _apiService.predictSample(
        image: _imageFile!,
        audio: _audioFile!,
        au: inputs.au,
        cu: inputs.cu,
        fe: inputs.fe,
        s: inputs.s,
        o: inputs.o,
      ),
    );
  }

  Future<void> _submitFingerprint() async {
    final inputs = _validateCommonInputs();
    if (inputs == null) {
      return;
    }

    final sampleId = _sampleIdController.text.trim();
    final site = _siteController.text.trim();
    final mineral = _mineralController.text.trim();

    if (sampleId.isEmpty || site.isEmpty || mineral.isEmpty) {
      _showError('sample_id, site, and mineral are required.');
      return;
    }

    await _sendRequest(
      () => _apiService.generateFingerprint(
        image: _imageFile!,
        audio: _audioFile!,
        au: inputs.au,
        cu: inputs.cu,
        fe: inputs.fe,
        s: inputs.s,
        o: inputs.o,
        sampleId: sampleId,
        site: site,
        mineral: mineral,
        userId: 'api_console',
        userName: 'API Console User',
      ),
    );
  }

  _ParsedInputs? _validateCommonInputs() {
    if (_imageFile == null || _audioFile == null) {
      _showError('Image and audio files are required.');
      return null;
    }

    final au = double.tryParse(_auController.text.trim());
    final cu = double.tryParse(_cuController.text.trim());
    final fe = double.tryParse(_feController.text.trim());
    final s = double.tryParse(_sController.text.trim());
    final o = double.tryParse(_oController.text.trim());

    if (au == null || cu == null || fe == null || s == null || o == null) {
      _showError('All chemical values must be valid numbers.');
      return null;
    }

    return _ParsedInputs(au: au, cu: cu, fe: fe, s: s, o: o);
  }

  Future<void> _sendRequest(
    Future<Map<String, dynamic>> Function() request,
  ) async {
    setState(() {
      _isLoading = true;
      _responseText = '';
    });

    try {
      final response = await request();
      final pretty = const JsonEncoder.withIndent('  ').convert(response);
      debugPrint(pretty);
      setState(() {
        _responseText = pretty;
      });
    } catch (error) {
      _showError(error.toString());
      setState(() {
        _responseText = error.toString();
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final content = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _FilePickerTile(
          label: 'Image',
          fileName: _imageFile?.name,
          onPick: _pickImage,
        ),
        const SizedBox(height: 12),
        _FilePickerTile(
          label: 'Audio (.wav)',
          fileName: _audioFile?.name,
          onPick: _pickAudio,
        ),
        const SizedBox(height: 16),
        _sectionHeader('Chemistry'),
        const SizedBox(height: 8),
        _chemicalFieldRow('Au', _auController),
        _chemicalFieldRow('Cu', _cuController),
        _chemicalFieldRow('Fe', _feController),
        _chemicalFieldRow('S', _sController),
        _chemicalFieldRow('O', _oController),
        const SizedBox(height: 16),
        _sectionHeader('Fingerprint metadata'),
        const SizedBox(height: 8),
        _textField('sample_id', _sampleIdController),
        _textField('site', _siteController),
        _textField('mineral', _mineralController),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: ElevatedButton(
                onPressed: _isLoading ? null : _submitPredict,
                child: const Text('Predict'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: ElevatedButton(
                onPressed: _isLoading ? null : _submitFingerprint,
                child: const Text('Generate Fingerprint'),
              ),
            ),
          ],
        ),
        if (_isLoading) ...[
          const SizedBox(height: 16),
          const LinearProgressIndicator(),
        ],
        if (_responseText.isNotEmpty) ...[
          const SizedBox(height: 16),
          _sectionHeader('Response'),
          const SizedBox(height: 8),
          SelectableText(_responseText),
        ],
      ],
    );

    final padded = Padding(
      padding: const EdgeInsets.all(16),
      child: content,
    );

    if (widget.embedded) {
      return padded;
    }

    return SingleChildScrollView(child: padded);
  }

  Widget _textField(String label, TextEditingController controller) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextField(
        controller: controller,
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
        ),
      ),
    );
  }

  Widget _chemicalFieldRow(String label, TextEditingController controller) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextField(
        controller: controller,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
        ),
      ),
    );
  }

  Widget _sectionHeader(String label) {
    return Text(
      label,
      style: Theme.of(context).textTheme.titleMedium,
    );
  }
}

class _FilePickerTile extends StatelessWidget {
  const _FilePickerTile({
    required this.label,
    required this.fileName,
    required this.onPick,
  });

  final String label;
  final String? fileName;
  final VoidCallback onPick;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: OutlinedButton.icon(
            onPressed: onPick,
            icon: const Icon(Icons.attach_file),
            label: Text(fileName == null ? 'Pick $label' : fileName!),
          ),
        ),
      ],
    );
  }
}

class _ParsedInputs {
  const _ParsedInputs({
    required this.au,
    required this.cu,
    required this.fe,
    required this.s,
    required this.o,
  });

  final double au;
  final double cu;
  final double fe;
  final double s;
  final double o;
}
