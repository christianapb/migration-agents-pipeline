class ErrorDeNegocio(Exception):
    # Error que se muestra al usuario con la plantilla error.html

    def __init__(self, estado, codigo, mensaje):
        super().__init__(mensaje)
        self.estado = estado
        self.codigo = codigo
        self.mensaje = mensaje
