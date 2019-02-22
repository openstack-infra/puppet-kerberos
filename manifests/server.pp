# Class kerberos::server

class kerberos::server (
  $realm,
  $admin_server = [$::fqdn],
  $kdcs         = [$::fqdn],
  $slave        = false,
  $slaves       = [],
) {

  include ::haveged

  $packages = [
    'krb5-admin-server',
    'krb5-kdc',
  ]
  package { $packages:
    ensure  => present,
  }

  file { '/etc/krb5kdc/kdc.conf':
    ensure  => present,
    replace => true,
    content => template('kerberos/kdc.conf.erb'),
    require => Package['krb5-kdc'],
  }

  file { '/etc/krb5kdc/kpropd.acl':
    ensure  => present,
    replace => true,
    content => template('kerberos/kpropd.acl.erb'),
    require => Package['krb5-kdc'],
  }

  file { '/etc/krb5kdc/kadm5.acl':
    ensure  => present,
    replace => true,
    source  => 'puppet:///modules/kerberos/kadm5.acl',
    require => Package['krb5-admin-server'],
  }

  file { '/var/krb5kdc':
    ensure => directory,
  }

  file { '/usr/local/bin/run-kprop.sh':
    ensure  => present,
    replace => true,
    mode    => '0755',
    content => template('kerberos/run-kprop.sh.erb'),
    require => Package['krb5-admin-server'],
  }

  if ($slave) {
    $run_kadmind = false  # Synonym for stopped
    $run_kpropd = true
    $kprop_cron = absent
  } else {
    $run_kadmind = true  # Synonym for running
    $run_kpropd = false
    $kprop_cron = present
  }

  cron { 'kprop':
    ensure      => $kprop_cron,
    user        => 'root',
    minute      => '*/15',
    command     => '/usr/local/bin/run-kprop.sh >/dev/null 2>&1',
    environment => 'PATH=/usr/bin:/bin:/usr/sbin:/sbin',
  }

  if ($::operatingsystem == 'Ubuntu') and ($::operatingsystemrelease >= '16.04') {
    # krb5-admin-server generates this, so make sure this runs after we do
    # things with krb5-admin-server
    file { '/etc/default/krb5-admin-server':
      ensure  => present,
      replace => true,
      content => template('kerberos/krb5-admin-server.defaults.new.erb'),
      require => Package['krb5-admin-server'],
    }

    file { '/etc/systemd/system/krb5-kpropd.service':
      ensure  => present,
      replace => true,
      source  => 'puppet:///modules/kerberos/krb5-kpropd.service',
      require => Package['krb5-admin-server'],
    }
    service { 'krb5-kpropd':
      ensure  => $run_kpropd,
      enable  => $run_kpropd,
      require => [
        File['/etc/systemd/system/krb5-kpropd.service'],
      ],
    }
    # This is a hack to make sure that systemd is aware of the new service
    # before we attempt to start it.
    exec { 'krb5-kpropd-systemd-daemon-reload':
      command     => '/bin/systemctl daemon-reload',
      before      => Service['krb5-kpropd'],
      subscribe   => File['/etc/systemd/system/krb5-kpropd.service'],
      refreshonly => true,
    }
  } else {
    # krb5-admin-server generates this, so make sure this runs after we do
    # things with krb5-admin-server
    file { '/etc/default/krb5-admin-server':
      ensure  => present,
      replace => true,
      content => template('kerberos/krb5-admin-server.defaults.erb'),
      require => Package['krb5-admin-server'],
    }

    file { '/etc/init.d/krb5-kpropd':
      ensure  => present,
      replace => true,
      source  => 'puppet:///modules/kerberos/krb5-kpropd',
      require => Package['krb5-admin-server'],
    }

    service { 'krb5-kpropd':
      ensure  => $run_kpropd,
      enable  => $run_kpropd,
      require => [
        File['/etc/init.d/krb5-kpropd'],
      ],
    }
  }

  service { 'krb5-admin-server':
    ensure    => $run_kadmind,
    enable    => $run_kadmind,
    subscribe => File['/etc/krb5kdc/kadm5.acl'],
    require   => [
      File['/etc/krb5kdc/kadm5.acl'],
      Package['krb5-admin-server'],
    ],
  }
}
