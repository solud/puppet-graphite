# == Class: graphite::config_gunicorn
#
# This class configures graphite/carbon/whisper and SHOULD NOT be
# called directly.
#
# === Parameters
#
# None.
#
class graphite::config_gunicorn inherits graphite::params {
  Exec { path => '/bin:/usr/bin:/usr/sbin' }

  case $::osfamily {

    'Debian': {
      $package_name = 'gunicorn'

      # Debian has a wrapper script called `gunicorn-debian` for multiple gunicorn
      # configs. Each config is stored as a separate file in /etc/gunicorn.d/.
      # On debian 8 and Ubuntu 15.10, which use systemd, the gunicorn-debian
      # config file has to be installed before the gunicorn package.
      file { '/etc/gunicorn.d/':
        ensure => directory,
      }
      file { '/etc/gunicorn.d/graphite':
        ensure  => file,
        content => template('graphite/etc/gunicorn.d/graphite.erb'),
        mode    => '0644',
        before  => Package[$package_name],
        require => File['/etc/gunicorn.d/'],
      }
    }

    'RedHat': {
      $package_name = 'python-gunicorn'

      # RedHat package is missing initscript
      if $::graphite::params::service_provider == 'systemd' {

        file { '/etc/systemd/system/gunicorn.service':
          ensure  => file,
          content => template('graphite/etc/systemd/gunicorn.service.erb'),
          mode    => '0644',
        }

        file { '/etc/systemd/system/gunicorn.socket':
          ensure  => file,
          content => template('graphite/etc/systemd/gunicorn.socket.erb'),
          mode    => '0755',
        }

        file { '/etc/tmpfiles.d/gunicorn.conf':
          ensure  => file,
          content => template('graphite/etc/tmpfiles.d/gunicorn.conf.erb'),
          mode    => '0644',
        }

        exec { 'gunicorn-reload-systemd':
          command => 'systemctl daemon-reload',
          path    => ['/usr/bin', '/usr/sbin', '/bin', '/sbin'],
          require => [
            File['/etc/systemd/system/gunicorn.service'],
            File['/etc/systemd/system/gunicorn.socket'],
            File['/etc/tmpfiles.d/gunicorn.conf'],
          ],
          before  => Service['gunicorn']
        }

      } elsif $::graphite::params::service_provider == 'redhat' {

        file { '/etc/init.d/gunicorn':
          ensure  => file,
          content => template('graphite/etc/init.d/RedHat/gunicorn.erb'),
          mode    => '0755',
          before  => Service['gunicorn'],
        }

      }

    }

    default: {
      fail("wsgi/gunicorn-based graphite is not supported on ${::operatingsystem} (only supported on Debian & RedHat)")
    }
  }

  # Only install gunicorn after graphite is ready to go
  package {
    $package_name:
      ensure  => installed,
      require => [
        File[$graphite::storage_dir_REAL],
        File[$graphite::graphiteweb_log_dir_REAL],
        Exec['Initial django db creation'],
      ];
  }

  service { 'gunicorn':
    ensure     => running,
    enable     => true,
    hasrestart => true,
    hasstatus  => false,
    require    => [
      Package[$package_name],
    ],
  }

}
