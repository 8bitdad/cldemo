class librenms::configure {
    exec { '/usr/bin/touch /tmp/puppet_once_lock':
      creates => '/tmp/puppet_once_lock',
      notify  => [Exec['/usr/sbin/a2enmod rewrite'],Exec['/usr/bin/php /var/www/librenms/build-base.php']],
      require => File["${install_dir}/config.php"],
    }

    exec { '/usr/sbin/a2enmod rewrite':
      refreshonly => true,
      require     => Exec['/usr/bin/touch /tmp/puppet_once_lock'],
    }

    exec { '/usr/bin/php /var/www/librenms/build-base.php':
      refreshonly => true,
      require     => Exec['/usr/bin/touch /tmp/puppet_once_lock'], Package['php5-cli'],
    }
}