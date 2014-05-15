class base::installer {
  package { 'tftpd-hpa':
    ensure => installed,
  }
  service { 'tftpd-hpa':
    ensure     => running,
    enable     => true,
    hasstatus  => true,
    hasrestart => true
  }
  file { '/etc/default/tftpd-hpa':
    ensure => present,
    owner  => 'root',
    group  => 'root',
    mode   => '0644',
    source => 'puppet:///modules/base/tftpd-hpa',
    notify => Service['tftpd-hpa']
  }
  file { '/var/www':
    source  => 'puppet:///modules/base/netboot',
    owner => 'root',
    group => 'root',
    recurse => true
  }
}