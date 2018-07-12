host { 'krbtest.openstack.ci':
  ensure       => present,
  host_aliases => 'krbtest',
  ip           => '127.0.1.1',
}

exec { 'set hostname':
  command => '/bin/hostname krbtest',
  unless  => '/usr/bin/test "$(/bin/hostname)" == "krbtest"',
}

class { 'kerberos::server':
  realm        => 'OPENSTACK.CI',
  kdcs         => [
    'krbtest.openstack.ci',
  ],
  admin_server => 'krbtest.openstack.ci',
  slaves       => [ ],
  slave        => false,
}

class { 'kerberos::client':
  admin_server => 'krbtest.openstack.ci',
  kdcs         => ['krbtest.openstack.ci'],
  realm        => 'OPENSTACK.CI',
}
