use jmaptest;

# This is about testing when there's no mailboxes, so you need a brand new
# account, basically.
attr pristine => 1;

test {
  my ($self) = @_;

  #my $account = $self->pristine_account;
  my $account = $self->any_account;
  my $tester  = $account->tester;

  subtest "No arguments" => sub {
    my $res = $tester->request([[
      "Mailbox/query" => {
        calculateTotal => jtrue(),
      },
    ]]);
    ok($res->is_success, "Mailbox/query")
      or diag explain $res->response_payload;

    jcmp_deeply(
      $res->single_sentence("Mailbox/query")->arguments,
      superhashof({
        accountId  => jstr($account->accountId),
        queryState => jstr(),
        position   => jnum(0),
        total      => jnum(0),
        ids        => [],
        canCalculateChanges => jbool(),
      }),
      "No mailboxes looks good",
    ) or diag explain $res->as_stripped_triples;
  };
};
