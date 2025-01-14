use jmaptest;

use Data::GUID qw(guid_string);

test {
  my ($self) = @_;

  my $account = $self->any_account;
  my $tester  = $account->tester;

  my $mbox = $account->create_mailbox;

  my ($create) = $tester->request_ok(
    [
      "Email/set" => {
        create => {
          new => {
            mailboxIds => { $mbox->id => jtrue },
            'header:from'    => 'Foo <test@example.org>',
            'header:subject' => 'a test subject',
            textBody => [
              {
                partId           => 'text',
              },
            ],
            attachments => [
              {
                partId      => 'attachment',
                type        => 'image/jpeg',
                cid         => 'fooz',
                language    => [ 'US' ],
                disposition => 'attachment',
                name        => 'image.jpg',
              },
            ],
            bodyValues => {
              text => {
                value => 'this is a text part',
              },
              attachment => {
                value => '{"name":"thing"}',
              },
            },
          },
        },
      },
    ],
    superhashof({
      created => {
        new => {
          id       => jstr(),
          size     => jnum(),
          blobId   => jstr(),
          threadId => jstr(),
        },
      },
    }),
    "attachments create"
  );

  my $new = $create->sentence(0)->arguments->{created}{new};
  my $id = $new->{id};
  ok($id, 'got the id');

  my %body = (
    blobId      => jstr(),
    charset     => 'utf-8',
    cid         => ignore(),
    disposition => undef,
    language    => undef,
    location    => undef,
    name        => undef,
    partId      => jstr(),
    size        => jnum(),
    type        => 'text/plain',
  );

  my ($res) = $tester->request_ok(
    [
      "Email/get" => {
        ids => [ $id ],
        fetchTextBodyValues => jtrue(),
      },
    ],
    superhashof({
      list => [
        {
          attachments => [
            {
              %body,
              type        => 'image/jpeg',
              charset     => undef,
              language    => [ 'US' ],
              disposition => 'attachment',
              name        => 'image.jpg',
              cid         => 'fooz',
            },
          ],
          bcc         => undef,
          blobId      => $new->{blobId},
          bodyValues  => ignore(), # will validate after
          cc          => undef,
          from        => [
            {
              name => 'Foo',
              email => 'test@example.org',
            },
          ],
          hasAttachment => jtrue(),
          htmlBody    => [ \%body ],
          id          => $id,
          inReplyTo   => undef,
          keywords    => ignore(),
          mailboxIds  => {
            $mbox->id => jtrue(),
          },
          messageId   => [ jstr(), ],
          preview     => jstr(),
          receivedAt  => re('^\d\d\d\d-\d\d-\d\dT\d\d:\d\d:\d\dZ\z'),
          references  => undef,
          replyTo     => undef,
          sender      => undef,
          sentAt      => re('\d\d\d\d-\d\d-\d\dT\d\d:\d\d:\d\d(Z|([+-]\d\d:\d\d))\z'),
          size        => jnum(),
          subject     => 'a test subject',
          textBody    => [ \%body ],
          threadId    => $new->{threadId},
          to          => undef,
        },
      ],
    }),
    'get looks good'
  );

  my $email = $res->sentence(0)->arguments->{list}[0];

  my $text_body = $email->{textBody}[0];
  my $body_value = $email->{bodyValues}{ $text_body->{partId} };

  ok($body_value, 'got our body value');
  jcmp_deeply(
    $body_value,
    {
      isEncodingProblem => jfalse(),
      isTruncated       => jfalse(),
      value             => 'this is a text part',
    },
  );
};
