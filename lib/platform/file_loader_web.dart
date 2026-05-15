// ignore_for_file: avoid_web_libraries_in_flutter, deprecated_member_use

import 'dart:async';
import 'dart:html' as html;

class LoadedFinanceFile {
  const LoadedFinanceFile({required this.name, required this.content});

  final String name;
  final String content;
}

Future<LoadedFinanceFile?> pickFinanceFile() async {
  final input = html.FileUploadInputElement()
    ..accept = '.csv,.tsv,.txt,.xlsx'
    ..multiple = false;
  input.click();

  await input.onChange.first;
  final file = input.files?.isNotEmpty == true ? input.files!.first : null;
  if (file == null) return null;

  if (file.name.toLowerCase().endsWith('.xlsx')) {
    return LoadedFinanceFile(
      name: file.name,
      content:
          '__XLSX_NOT_SUPPORTED__\nPor ahora carga el archivo exportado desde Excel como CSV o TSV. El parser XLSX real requiere agregar una libreria o backend.',
    );
  }

  final reader = html.FileReader();
  final completer = Completer<String>();
  reader.onLoad.listen((_) => completer.complete(reader.result as String));
  reader.onError.listen(
    (_) => completer.completeError('No pude leer el archivo.'),
  );
  reader.readAsText(file);

  return LoadedFinanceFile(name: file.name, content: await completer.future);
}
