/** Error controlado que el errorHandler convierte en respuesta JSON con su código HTTP. */
export class HttpError extends Error {
  constructor(status, mensaje, codigo) {
    super(mensaje);
    this.status = status;
    this.codigo = codigo;
  }

  static badRequest(mensaje, codigo = 'SOLICITUD_INVALIDA') {
    return new HttpError(400, mensaje, codigo);
  }

  static unauthorized(mensaje = 'Necesitas iniciar sesión', codigo = 'NO_AUTENTICADO') {
    return new HttpError(401, mensaje, codigo);
  }

  static forbidden(mensaje = 'No tienes permiso para esta acción', codigo = 'SIN_PERMISO') {
    return new HttpError(403, mensaje, codigo);
  }

  static notFound(mensaje = 'Recurso no encontrado', codigo = 'NO_ENCONTRADO') {
    return new HttpError(404, mensaje, codigo);
  }

  static conflict(mensaje, codigo = 'CONFLICTO') {
    return new HttpError(409, mensaje, codigo);
  }
}
