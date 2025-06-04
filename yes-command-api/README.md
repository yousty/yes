# Yes Command API

The Yes command API is a mountable rails engine providing an endpoint for calling API commands.

Commands represent the write side of CQRS in our eventsourced system.

## Installation
Add this line to your application's Gemfile:

```ruby
gem "yes-command-api"
```

And then execute:
```bash
$ bundle
```

Or install it yourself as:
```bash
$ gem install yes-command-api
```

## Usage

### Configuration

The preferred way of issuing commands using the commands api is asyncronously.

For that, you need to configure yousty eventsourcing to not process commands inline.

You most likely also want to configure a notifier to notify command progress. The notifier will be
called when a batch of commands starts and finishes, and also whenever a single command of the batch has finished processing.

```ruby
Yousty::Eventsourcing.configure do |config|
  config.process_commands_inline = false
  config.command_notifier_class = Yousty::Eventsourcing::CommandNotifiers::MessageBusNotifier
end
```
If `process_commands_inline` is true, commands will be processed using the currently configured ActiveJob adapter.


### Mounting the Endpoint

Mount the command endpoint to your rails application in `config/routes.rb`:

```ruby
Rails.application.routes.draw do
  mount Yes::Command::Api::Engine => '/v1/commands'
end
```

The mounted endpoint exposes all commands defined in your bounded context(s).


### Writing Authorizers

To make a command accessible for a caller, you need to define an authorizer for it.
If there is no authorizer defined a command is considered unauthorized for all callers by default.

Example:

Given a command

```ruby
module MyContext
  module Commands
    module MyAggregate
      class DoSomething
        attribute :what, Yousty::Eventsourcing::Types::String
        attribute :user_id, Yousty::Eventsourcing::Types::UUID
        alias aggregate_id user_id
      end
    end
  end
end
```

A simple authorizer could look like this:

```ruby
module MyContext
  module Commands
    module MyAggregate
      class DoSomethingAuthorizer < Yousty::Eventsourcing::CommandAuthorizer
        # @param command [Yousty::Eventsourcing::Command]
        # @param auth_data [Hash]
        def self.call(command, auth_data)
          raise CommandNotAuthorized if command.user_id != auth_data['user_id']
          raise CommandNotAuthorized if command.what != 'Nonsense'
        end
      end
    end
  end
end
```

The authorizer needs to raise `CommandNotAuthorized` if the given `auth_data` (jwt payload + referer host) does not authorize the given `command`.
In case the authorizer raises nothing, the command is considered authorized.


### Making a Command(s) Request

The commands endpoint accepts commands supplied as a json array, using a POST request.

The endpoint is located where you mounted it, if you followed the steps above it will be for yousty at `https://api.yousty.ch/your_service_context/v1/commands`.

Here is an example of a valid payload:

```json
{
  "commands": [{
    "subject": "MyAggregate",
    "context": "MyContext",
    "command": "DoSomething",
    "data": {
      "user_id": "07393424-fa57-40fe-a3d2-c3bdd8b8e952",
      "what": "Nonsense"
    }
  }],
  "channel": "/notifications-for-user-07393424-fa57-40fe-a3d2-c3bdd8b8e952"
}
```
You also need to supply a valid JWT token for a yousty user as a bearer token for authorization and authentication.

Note that commands is an array, so you can supply any number of commands in a single request.

See the next section for how to receive updates about your commands using the standard message bus notifier.

### MessageBus Notifier

#### Authorization

In order to receive user-targeted messages - you should authorize your request first. It can be done by providing JWT token along with `Authorization` header. Example:

```javascript
let headers = { 'Authorization': 'Token eyJhbGciOiJFRDI1NTE5In0.eyJzY29wZXMiOlsiYWRtaW4iLCJjdXJyZW50X3VzZXIiLCJ1c2VyX3Byb2ZpbGUiXSwiZGF0YSI6eyJ1c2VyX3V1aWQiOiIyMjUwODIwZS00MzVhLTQ0ODQtYWUzMS1iYTFiODk1NDI2MWUifSwiZXhwIjoxNjkxNzQwNTA3fQ.D_TuOKh5LyGtusU5cZrJih-WYbB7MWChDOTS6WcWCRZUdldzZzKmXLtdgE93bkgb0TV9FNKXSvHt8DLhBZIoCA' };
```

#### Filters

You can filter messages by providing filter params in the request url. Here they are:

- `batch_id`. It is your command batch id. Example: `/message-bus/some-client-id/poll?batch_id=7121e60e-4d3d-4fb7-b454-f603c75f1359`
- `type`. It is a command type. Possible values are `batch_started`, `batch_finished`, `command_success` and `command_error` so far. Example: `/message-bus/some-client-id/poll?type=command_error`
- `command`. It is a command name. Example `/message-bus/some-client-id/poll?command=ApprenticeshipPresentation::Apprenticeship::Commands::AssignCompany::Command`
- `since`. Unix timestamp. Providing it will filter messages which are not older than the `since` param value. Example: `/message-bus/some-client-id/poll?since=1689778808`

You can provide a starting message id to start receiving messages from certain position. As stated in docs - you should pass it in the payload along with a channel name to subscribe to:

```ruby
let payload = { 'some-channel-name': 123 }
```

#### Examples

Here is how long-polling HTTP request from browser using various filters and JWT authorization may look like:

```javascript
async function postData(url = "", data = {}) {
    // Default options are marked with *
    const response = fetch(url, {
        method: "POST", // *GET, POST, PUT, DELETE, etc.
        mode: "same-origin", // no-cors, *cors, same-origin
        cache: "no-cache", // *default, no-cache, reload, force-cache, only-if-cached
        credentials: "same-origin", // include, *same-origin, omit
        headers: {
            'Content-Type': 'application/json',
            'X-SILENCE-LOGGER': 'true',
            'Transfer-Encoding': 'chunked',
            'Authorization': 'Token eyJhbGciOiJFRDI1NTE5In0.eyJzY29wZXMiOlsiYWRtaW4iXSwiZGF0YSI6eyJ1c2VyX3V1aWQiOiJlMmMwYzBkNC1iMWMzLTQwNzktOTlhMi0zYTlhOTg2MWVhYzgifSwiZXhwIjoxNjg5NzgzMjE4fQ.HKmthrv7HDsMof88hvCErVSlTCGg-Ikeb9-eb0DLPVXQQmpJ_4gTD52bgMFBGmGaA_TdRakAG3UGgCp9d9VYAw'
        },
        redirect: "error", // manual, *follow, error
        referrerPolicy: "no-referrer", // no-referrer, *no-referrer-when-downgrade, origin, origin-when-cross-origin, same-origin, strict-origin, strict-origin-when-cross-origin, unsafe-url
        body: JSON.stringify(data), // body data type must match "Content-Type" header
    });
    return response;
}

function processChunkedResponse(response) {
    var text = '';
    var reader = response.body.getReader()
    var decoder = new TextDecoder();

    return readChunk();

    function readChunk() {
        return reader.read().then(appendChunks);
    }

    function appendChunks(result) {
        var chunk = decoder.decode(result.value || new Uint8Array, {stream: !result.done});
        console.log('got chunk of', chunk.length, 'bytes')
        console.log('chunk so far is', chunk);
        text += chunk;

        if (result.done) {
            return text;
        } else {
            return readChunk();
        }
    }
}
//let url = 'http://localhost:3000/message-bus/some-client-id/poll?since=1689778808&type=batch_started&batch_id=7121e60e-4d3d-4fb7-b454-f603c75f1359&command=ApprenticeshipPresentation::Apprenticeship::Commands::AssignCompany::Command'
let url = new URL('http://localhost:3000/message-bus/some-client-id/poll');
url.search = new URLSearchParams(
    {
        since: 1689778808,
        type: 'batch_started',
        batch_id: '7121e60e-4d3d-4fb7-b454-f603c75f1359',
        command: 'ApprenticeshipPresentation::Apprenticeship::Commands::AssignCompany::Command'
    }
);

postData(url, { '/notifications/testing-12345678': 0 }).then(processChunkedResponse);
```

## Development

You will have to install Docker first. It is needed to run EventStore DB. You can run EventStore DB with this command:

```shell
docker compose up
```

Run setup script:
```ruby
bin/setup_db
```

Now you can enter a dev console by running `bin/console` or run tests by running the `rspec` command.

To install this gem onto your local machine, run `bundle exec rake install`. To release a new version, update the version number in `version.rb` add description for released changes in `CHANGELOG.md` if necessary update `README.md`, and then run `bundle exec rake release`, which will create a git tag for the version, push git commits and the created tag, and push the `.gem` file to `gem.fury.io`. In order to push new releases you need to provide `GEM_FURY_PUSH_TOKEN` env variable.
