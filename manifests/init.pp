include ::stdlib
include ::augeas
include ::sysstat
include ::wget
include ::lsststack

Class['lsststack'] -> File['newinstall.sh']

$stack_user  = $::lsst_stack_user ? {
  undef   => 'lsstsw',
  default => $::lsst_stack_user,
}
$stack_group = $stack_user
$stack_path = "/home/${stack_user}/stack"

$wheel_group = $::osfamily ? {
  'Debian' => 'sudo',
  default  => 'wheel',
}

case $::osfamily {
  'Debian': {
    $convience_pkgs = [
      'screen',
      'tree',
      'vim'
    ]
  }
  'RedHat': {
    include ::epel
    Class['epel'] -> Package<| provider == 'yum' |>

    $convience_pkgs = [
      'screen',
      'tree',
      'vim-enhanced'
    ]
  }
  default: { fail() }
}

package { $convience_pkgs: }

$memoryrequired = to_bytes('16 GB')
$swaprequired = $memoryrequired - to_bytes($::memorysize)

if $swaprequired >= to_bytes('1 GB') {
  $ensure_swap = 'present'
} else {
  $ensure_swap = 'absent'
}

class { 'swap_file':
  ensure       => $ensure_swap,
  swapfilesize => $swaprequired,
}

user { $stack_user:
  ensure     => present,
  gid        => $stack_group,
  groups     => [$wheel_group],
  managehome => true,
}

group { $stack_group:
  ensure => present,
}

file { 'stack':
  ensure  => directory,
  owner   => $stack_user,
  group   => $stack_group,
  mode    => '0755',
  path    => $stack_path,
  require => Class['swap_file'],
}

wget::fetch { 'newinstall.sh':
  source      => 'https://sw.lsstcorp.org/eupspkg/newinstall.sh',
  destination => "${stack_path}/newinstall.sh",
  execuser    => $stack_user,
  timeout     => 60,
  verbose     => true,
  require     => File['stack'],
}

file { 'newinstall.sh':
  mode    => '0755',
  path    => "${stack_path}/newinstall.sh",
  require => Wget::Fetch['newinstall.sh'],
}

exec { 'newinstall.sh':
  environment => ["PWD=${stack_path}"],
  command     => 'echo -e "yes\nyes" | newinstall.sh -c',
  path        => ['/bin', '/usr/bin', $stack_path],
  cwd         => $stack_path,
  user        => $stack_user,
  logoutput   => true,
  creates     => "${stack_path}/loadLSST.zsh",
  timeout     => 900,
  require     => File['newinstall.sh'],
}
