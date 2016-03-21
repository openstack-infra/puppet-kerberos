# Class kerberos::client

class kerberos::client (
  $admin_server,
  $kdcs,
  $realm,
) {

  include ::ntp

  if ($::osfamily == 'RedHat') {
    $kerberos_client = 'krb5-workstation'
  } else {
    $kerberos_client = 'krb5-user'
  }

  package { $kerberos_client:
    ensure  => present,
    require => File['/etc/krb5.conf'],
  }

  file { '/etc/krb5.conf':
    ensure  => present,
    replace => true,
    content => template('kerberos/krb5.conf.erb'),
  }
}
