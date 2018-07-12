require 'puppet-openstack_infra_spec_helper/spec_helper_acceptance'

describe 'kerberos', if: os[:family] == 'ubuntu' do

  def pp_path
    base_path = File.dirname(__FILE__)
    File.join(base_path, 'fixtures')
  end

  def puppet_manifest
    manifest_path = File.join(pp_path, 'default.pp')
    File.read(manifest_path)
  end

  it 'should work with no errors' do
    apply_manifest(puppet_manifest, catch_failures: true)
  end

  # Realm needs to be manually set up before admin service will start
  it 'set up the kerberos realm' do
    shell('yes krbpass | krb5_newrealm')
    shell('echo "addprinc -randkey host/krbtest.openstack.ci" | kadmin.local')
    shell('echo "ktadd host/krbtest.openstack.ci" | kadmin.local')
    shell('echo "addprinc -pw rootpw root@OPENSTACK.CI" | kadmin.local')
  end

  it 'should be idempotent' do
    apply_manifest(puppet_manifest, catch_changes: true)
  end

  describe command('echo rootpw | kinit') do
    its(:exit_status) { should eq 0 }
  end

end
