import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

void main() {
  runApp(const Add());
}

class Add extends StatelessWidget {
  const Add({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter',
      theme: ThemeData(

        colorScheme: .fromSeed(seedColor: Colors.indigo),
      ),
      home: const MyHomePage(title: 'Lista de Tareas'),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key, required this.title});

  final String title;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  final TextEditingController _nombreController = TextEditingController();
  DateTime? _fechaSeleccionada;

  void _abrirCalendario() async {
    DateTime? fecha = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );

    if (fecha != null) {
      setState(() {
        _fechaSeleccionada = fecha;
      });
    }
  }

  Future<void> _guardar() async {

    // PASO 1 — Validar que no estén vacíos
    if (_nombreController.text.isEmpty || _fechaSeleccionada == null) {
      // mostrar error y parar
      return;
    }

    // PASO 2 — Enviar a Firestore
    await FirebaseFirestore.instance
        .collection('tareas')  // 👈 nombre de la colección
        .add({                         // 👈 crea un documento nuevo
      'nombre': _nombreController.text.trim(), // texto del TextField
      'fechaLimite': Timestamp.fromDate(_fechaSeleccionada!), // fecha elegida
      'fechaCreacion': Timestamp.fromDate(DateTime.now()), // fecha de creación
      'fechaRealizacion': null, // fecha de realización (aún no completada)
      'hecho': false, // estado de la tarea
    });

  }

  @override
  Widget build(BuildContext context) {

    return Scaffold(
      appBar: AppBar(

        backgroundColor: Theme.of(context).colorScheme.inversePrimary,

        title: Text(widget.title),
      ),
      body: Center(

        child: Column(

          mainAxisAlignment: .spaceAround,
          children: [
            TextField(
              controller: _nombreController,
              decoration: InputDecoration(
              hintText: 'Ingrese una tarea',
                border: const OutlineInputBorder(),
              ),
            ),
            Text(
              _fechaSeleccionada == null
                  ? 'Sin fecha'
                  : 'Fecha límite: ${_fechaSeleccionada!.day}/${_fechaSeleccionada!.month}/${_fechaSeleccionada!.year}',
            ),
            ElevatedButton(
              onPressed: _abrirCalendario,
              child: Text('Seleccionar fecha límite'),
            ),

            ElevatedButton(onPressed: () async {
              await _guardar();
              Navigator.pop(context);
            }, child: Text('Guardar Tarea')),

            ElevatedButton(onPressed: () {
              Navigator.pop(context);
            }, child: Text('Volver')),
          ],
        ),
      ),
    );
  }
}
