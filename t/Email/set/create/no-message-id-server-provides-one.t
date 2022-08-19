use jmaptest;

test {
  my ($self) = @_;

  my $account = $self->any_account;
  my $tester  = $account->tester;

  my $mbox = $account->create_mailbox;

  my ($set_res) = $tester->request_ok(
    [
      "Email/set" => {
        create => {
          new => {
            mailboxIds => { $mbox->id => \1, },
            subject => 'foo',
          },
        },
      },
    ],
    superhashof({
      created => {
        new => superhashof({
          id => jstr(),
        }),
      },
    }),
    "minimum required properties provided gives good response",
  );

  my $created_id = $set_res->sentence(0)->as_set->created_id('new');

  $tester->request_ok(
    [
      "Email/get" => {
        ids => [ $created_id ],
        properties => [ 'messageId', 'id' ],
      },
    ],
    superhashof({
      list => [
        {
          id        => $created_id,
          messageId => [ jstr ],
        },
      ],
    }),
    "a message-id header was generated for us",
  );
};
