# **Deploy de Paparuta en AWS**

![Captura del sitio web](/documentacion/capturas/ReadmePage.png)

## Descripcion
Paparuta es un servicio de turismo que te invita a explorar la decima region de Chile a travez de sus locales de Papa Jonh's. 
Una experiencia que invita a los amantes de la pizza a explorar esta maravillosa region

---

## integrantes.
- Leonardo Jofre
- Emilia Osores

## IP publica del deploy.
- URL de Amazon [papa-alb-20260612-110737-2115880245.us-east-1.elb.amazonaws.com](http://papa-alb-20260612-110737-2115880245.us-east-1.elb.amazonaws.com/)
- URL con DNS a dominio [paparuta.maidkissa.moe](http://paparuta.maidkissa.moe/)

## Requisitos previos.
- AWS CLI
- less (requerido por AWS cli como pager)
- Credenciales configuradas con:
  ```bash
  aws configure
  ```
  con region en `us-east-1` y output en `json`

---

## Instrucciones de ejecucion.
```bash
git clone https://github.com/schismatiic/lab2_taller_papayon.git
cd lab2_taller_papayon
chmod +x infraestructura/deploy.sh
chmod +x infraestructura/cleanup.sh
./infraestructura/deploy.sh
```

- Al ejecutar el script este creara recursos de en AWS que pueden ser removidos ejecutando
```bash
./infraestructura/cleanup.sh
```

---

## Documentacion.
- Arquitectura `/documentacion/arquitectura.pdf`
- Proceso `/documentacion/capturas/`
