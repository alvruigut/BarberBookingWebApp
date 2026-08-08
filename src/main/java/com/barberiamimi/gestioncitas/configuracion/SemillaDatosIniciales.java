package com.barberiamimi.gestioncitas.configuracion;

import com.barberiamimi.gestioncitas.entidad.Barberia;
import com.barberiamimi.gestioncitas.entidad.Profesional;
import com.barberiamimi.gestioncitas.entidad.UsuarioAdministracion;
import com.barberiamimi.gestioncitas.enumeracion.RolUsuario;
import com.barberiamimi.gestioncitas.repositorio.RepositorioBarberia;
import com.barberiamimi.gestioncitas.repositorio.RepositorioProfesional;
import com.barberiamimi.gestioncitas.repositorio.RepositorioUsuarioAdministracion;
import org.springframework.boot.ApplicationArguments;
import org.springframework.boot.ApplicationRunner;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.stereotype.Component;
import org.springframework.transaction.annotation.Transactional;

@Component
public class SemillaDatosIniciales implements ApplicationRunner {
    private static final String SLUG_BARBERIA = "barberia-mimi";
    private static final String USUARIO_PROPIETARIO = "mimi";

    private final RepositorioBarberia barberias;
    private final RepositorioProfesional profesionales;
    private final RepositorioUsuarioAdministracion usuarios;
    private final PasswordEncoder codificador;

    public SemillaDatosIniciales(RepositorioBarberia barberias,
                                 RepositorioProfesional profesionales,
                                 RepositorioUsuarioAdministracion usuarios,
                                 PasswordEncoder codificador) {
        this.barberias = barberias;
        this.profesionales = profesionales;
        this.usuarios = usuarios;
        this.codificador = codificador;
    }

    @Override
    @Transactional
    public void run(ApplicationArguments argumentos) {
        if (usuarios.findByNombreUsuario(USUARIO_PROPIETARIO).isPresent()) return;

        Barberia barberia = barberias.findBySlug(SLUG_BARBERIA)
            .orElseGet(() -> barberias.save(new Barberia("MimisBarber", SLUG_BARBERIA)));

        Profesional propietario = profesionales.findByBarberiaIdOrderByNombre(barberia.getId()).stream()
            .filter(profesional -> "mimi".equalsIgnoreCase(profesional.getAlias()))
            .findFirst()
            .orElseGet(() -> profesionales.save(new Profesional(barberia, "Mimi", "mimi")));

        usuarios.save(new UsuarioAdministracion(
            barberia,
            propietario,
            USUARIO_PROPIETARIO,
            codificador.encode("mimi123"),
            RolUsuario.PROPIETARIO
        ));
    }
}
