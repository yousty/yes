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

For that, you need to configure Yes::Core to process commands asynchronously.

```ruby
Yes::Core.configure do |config|
  config.process_commands_inline = false
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
  module MyAggregate
    class Aggregate < Yes::Core::Aggregate
      attribute :what, :string, command: true
      attribute :user_id, :uuid

      authorize do
        command.user_id == auth_data['user_id']
      end
    end
  end
end
```

The authorizer needs to raise `CommandNotAuthorized` if the given `auth_data` (jwt payload + referer host) does not authorize the given `command`.
In case the authorizer raises nothing, the command is considered authorized.


### Making a Command(s) Request

The commands endpoint accepts commands supplied as a json array, using a POST request.

The endpoint is located where you mounted it, e.g. `https://your-app.example.com/v1/commands`.

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
You also need to supply a valid JWT token as a bearer token for authorization and authentication.

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

### Prerequisites

- Docker and Docker Compose
- Ruby >= 3.2.0
- Bundler

### Setup

Start PostgreSQL and Redis from the **repository root**:

```shell
docker compose up -d
```

Install dependencies:

```shell
bundle install
```

Set up the EventStore database:

```shell
PG_EVENTSTORE_URI="postgresql://postgres:postgres@localhost:5532/eventstore_test" bundle exec rake pg_eventstore:create pg_eventstore:migrate
```

Set up the test database:

```shell
RAILS_ENV=test bundle exec rake db:create db:migrate
```

The `.env` file at `spec/.env` is loaded automatically and contains JWT test keys.

### Running Specs

```shell
bundle exec rspec
```

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/yousty/yes.

## License

The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).
