# TODO for rai

- [x] sshing to the machine fails if the project doesn't exist there yet. That's not ideal.
- [x] rai-cp should also be able to handle full paths outside of git repositories (for example for ssh-key uploads).
- [x] rai should be independent of cloud provider - in time I want to run it on my own physical machine with some hypervisor set up.
- [] rai-push doesn't switch the current branch. It should.
- [x] should save things to files in the repo (like username, remote machine name, etc.), and also allow overrides in the home folder.
- [] got an error with `rai-ssh`: bash: warning: setlocale: LC_CTYPE: cannot change locale (UTF-8): No such file or directory
- [x] rai-config warns with the following, but succeeds:
  ```
  /rai/rai-config: line 21: declare: -A: invalid option
  declare: usage: declare [-afFirtx] [-p] [name[=value] ...]
  /rai/rai-config: line 24: _rai_preset[$_rai_var]: bad array subscript
  ```
- [] rai-push needs to force-push (or force-with-lease). I often make changes to the commits afterwards.
