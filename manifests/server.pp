# Class kerberos::server

class kerberos::server (
  $realm,
  $admin_server = [$::fdqn],
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

  file { '/etc/init.d/krb5-kpropd':
    ensure  => present,
    replace => true,
    source  => 'puppet:///modules/kerberos/krb5-kpropd',
    require => Package['krb5-admin-server'],
  }

  file { '/usr/local/bin/run-kprop.sh':
    ensure  => present,
    replace => true,
    mode    => '0755',
    content => template('kerberos/run-kprop.sh.erb'),
    require => Package['krb5-admin-server'],
  }

  if ($slave) {
    $run_admin_server = stopped
    $run_kadmind = false
    $run_kpropd = running
    $kprop_cron = absent
  } else {
    $run_admin_server = running
    $run_kadmind = true
    $run_kpropd = stopped
    $kprop_cron = present
  }

  # krb5-admin-server generates this, so make sure this runs after we do
  # things with krb5-admin-server
  file { '/etc/default/krb5-admin-server':
    ensure  => present,
    replace => true,
    content => template('kerberos/krb5-admin-server.defaults.erb'),
    require => Package['krb5-admin-server'],
  }

  cron { 'kprop':
    ensure      => $kprop_cron,
    user        => 'root',
    minute      => '*/15',
    command     => '/usr/local/bin/run-kprop.sh >/dev/null 2>&1',
    environment => 'PATH=/usr/bin:/bin:/usr/sbin:/sbin',
  }

  service { 'krb5-kpropd':
    ensure  => $run_kpropd,
    require => [
      File['/etc/init.d/krb5-kpropd'],
      Package['krb5-admin-server'],
    ],
  }

  service { 'krb5-admin-server':
    ensure    => $run_admin_server,
    subscribe => File['/etc/krb5kdc/kadm5.acl'],
    require   => [
      File['/etc/krb5kdc/kadm5.acl'],
      Package['krb5-admin-server'],
    ],
  }
}
