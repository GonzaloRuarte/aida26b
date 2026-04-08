Estamos en la facultad de ciencias exactas de la UBA. Estoy con los alumnos por empezar un sisstema nuevo. Vamos a trabajar en TypeScript, ndoe.js, vanillaTs en el frontend, Postgresql. 

Vamos con un producto mínimo. La descripción del sistema es:

Una facultad quiere desarrollar un sistema que integre todos sus procesos empezando por los resultados académicos de los alumnos. Quieren tener automatizado el criterio para identificar los alumnos que cumplen las condiciones para pedir su título de grado. Teniendo la información de carreras, planes de estudio y actas, desean también generar los certificados de alumno regular y hacer estadísticas (alumnos activos, egresados, los que interrumpieron la carrera, el tiempo que lleva recibirse, etc...).

Y quiero empezar por los CRUD de alumnos, materias e inscripciones (de alumno a manteria).  No quermos id autonuméricos, los alumnos tienen su número de libreta y las materias un cod_mat, para inscripciones la pk será compuesta.

Tiene que mostrar una grilla en la UI para cada tabla, con un botón borrar y editar en cada renglón, el botón editar va a un formulario. Tiene que haber un botón agregar para un formulario nuevo. Esto es tanto para materias como para alumnos.

Por ahora no hay seguridad ni usaurios. 

Quiero los sql para crear la base y en el mismo repo el frontend y el backend (que pueden estar en carpetas distintas).

El código y los comentarios los queremos en inglés, las leyendas bilingües según la preferencia del usuario, la documentación en castellano. 