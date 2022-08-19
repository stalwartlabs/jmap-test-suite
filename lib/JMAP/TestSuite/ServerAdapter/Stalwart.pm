package JMAP::TestSuite::ServerAdapter::Stalwart;
use Moose;
with 'JMAP::TestSuite::ServerAdapter';

use Process::Status;
use Data::GUID qw(guid_string);
use Mail::IMAPClient;

has base_uri => (
  is => 'ro',
  required => 1,
);

sub can_use_websockets { 1 }

has saslpasswd2_path => (
  is => 'ro',
  default => 'saslpasswd2',
);

has no_sasl => (
  is => 'ro',
);

has virtual_domain => (
  is      => 'ro',
  default => 'localhost',
);

has virtual_domain_enabled => (
  is      => 'ro',
  default => '0',
);

has stalwart_prefix => (
  is      => 'ro',
  default => '/usr/stalwart/',
);

has stalwart_host => (
  is => 'ro',
  default => 'localhost',
);

has stalwart_port => (
  is => 'ro',
);

has stalwart_admin_user => (
  is => 'ro',
  default => 'imapuser',
);

has stalwart_admin_pass => (
  is => 'ro',
  default => 'secret',
);

has stalwart_admin_use_ssl => (
  is => 'ro',
  default => 0,
);

has stalwart_hierarchy_separator => (
  is => 'ro',
  default => '/',
);

has credentials => (
  isa => 'ArrayRef[HashRef]',
  traits  => [ 'Array' ],
  handles => { credentials => 'elements' },
  required => 1,
);

has imap_client => (
  is  => 'ro',
  isa => 'Mail::IMAPClient',
  lazy => 1,
  default => sub {
    my ($self) = @_;

    Mail::IMAPClient->new(
      Server   => $self->stalwart_host,
      Port     => $self->stalwart_port,
      Ssl      => $self->stalwart_admin_use_ssl ? 1 : 0,

      User     => $self->stalwart_admin_user,
      Password => $self->stalwart_admin_pass,
      Uid      => 1,
    ) or die "Failed to connect to stalwart imap: $@\n";
  },
);

sub any_account {
  my ($self) = @_;

  my ($credentials) = $self->credentials;

  # Is it okay to require the credentials to have the accountId?  If we don't
  # do that, we need to make accounts' accountId only be known on demand.  Or
  # we could authenticate eagerly on Simple accounts.  For now, I'll do the
  # simplest thing I've thought of: this. -- rjbs, 2016-11-18
  # ^^ This comment stolen from the Simple account.
  my $account_id = $credentials->{accountId};

  if ($self->virtual_domain_enabled) {
    my $virtual_domain = $self->virtual_domain;
    $account_id =~ s/\@\Q$virtual_domain\E$//i;
  }

  return JMAP::TestSuite::Account::Stalwart->new({
    server      => $self,
    accountId   => $account_id,
    credentials => $credentials,
  });
}

sub pristine_account {
  my ($self) = @_;

  # XXX - Do something far less janky. -- alh, 2018-02-21
  # These must be lowercase or stalwart can't auth them
  my $user = "jt-" . lc guid_string();

  unless ($self->no_sasl) {
    my $sasl = $self->saslpasswd2_path;

    my $res = `echo 'mypassword' | $sasl -p -c $user 2>&1`;
    my $ps = Process::Status->new;

    unless ($ps->is_success) {
      die "Failed to create sasl auth for new user. Got output: $res\n";
    }
  }

  my $sep = $self->stalwart_hierarchy_separator;

  my $folder = "user$sep$user\@localhost";

  unless ($self->imap_client->create($folder)) {
    die "Failed to create folder '$folder': $@\n";
  }

  my $username = "$user\@localhost";

  my $account_id = $username;

  if ($self->virtual_domain_enabled) {
    my $virtual_domain = $self->virtual_domain;
    $account_id =~ s/\@\Q$virtual_domain\E$//i;
  }

  return JMAP::TestSuite::Account::Stalwart->new({
    server      => $self,
    accountId   => $account_id,
    credentials => {
      username => $username,
      password => 'mypassword',
    },
  });
}

package JMAP::TestSuite::Account::Stalwart {
  use Moose;
  with 'JMAP::TestSuite::Account';

  use MIME::Base64 ();

  has credentials => (is => 'ro', required => 1);

  sub authenticated_tester {
    my ($self) = @_;

    if ($self->server->use_websockets) {
      return $self->authenticated_websocket_tester;
    }

    return $self->authenticated_http_tester;
  }

  sub authenticated_http_tester {
    my ($self) = @_;

    my $base = $self->server->base_uri =~ s{/\z}{}r;

    my $auth = join q{:}, @{ $self->credentials }{ qw(username password) };

    require JMAP::TestSuite::JMAP::Tester::WithSugar;

    my $tester = JMAP::TestSuite::JMAP::Tester::WithSugar->new({
      api_uri    => "$base/jmap/",
      upload_uri => "$base/jmap/upload/" . $self->credentials->{accountId} . "/",
      download_uri => "$base/jmap/download/{accountId}/{blobId}/{name}/",
      default_arguments => { accountId =>  $self->credentials->{accountId}  },
    });

    $tester->ua->set_default_header(
      Authorization => 'Basic ' . MIME::Base64::encode_base64($auth, ''),
    );

    return $tester;
  }

  sub authenticated_websocket_tester {
    my ($self) = @_;

    my $base = $self->server->base_uri =~ s{/\z}{}r;
    (my $ws_base = $base) =~ s/^https?/ws/;

    my $auth = join q{:}, @{ $self->credentials }{ qw(username password) };

    require JMAP::TestSuite::JMAP::Tester::WebSocket::WithSugar;

    my $tester = JMAP::TestSuite::JMAP::Tester::WebSocket::WithSugar->new({
      api_uri    => "$base/jmap/",
      upload_uri => "$base/jmap/upload/" . $self->credentials->{username} . "/",
      download_uri => "$base/jmap/download/{accountId}/{blobId}/{name}/",
      ws_api_uri => "$ws_base/jmap/ws/",
      authorization => 'Basic ' . MIME::Base64::encode_base64($auth, ''),
    });

    $tester->ua->set_default_header(
      Authorization => 'Basic ' . MIME::Base64::encode_base64($auth, ''),
    );

    return $tester;
  }

  no Moose;
  __PACKAGE__->meta->make_immutable;
}

no Moose;
__PACKAGE__->meta->make_immutable;
