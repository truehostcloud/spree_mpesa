# Spree M-Pesa

Direct **M-Pesa paybill** payment method for Spree Commerce, using the Safaricom
**Daraja STK Push** API, no third-party aggregator (and no aggregator fees).

It adds `Spree::PaymentMethod::Mpesa`, which a
merchant configures in the Spree admin with **their own** paybill credentials, so money
settles straight into the merchant's own M-Pesa account.

## Compatibility

- Spree `>= 5.0, < 6.0`
- Ruby `>= 3.0`

## What a merchant needs (from the Safaricom Daraja portal)

- Paybill **shortcode**
- **Consumer key** + **consumer secret**
- **Passkey**

Each merchant supplies their own. Nothing is hard-coded or shared, and the company never
holds the funds.

## Configuring it in the admin

The payment method form (Spree admin → Payment Methods → M-Pesa) shows a short guide and
four fields. A merchant gets the values from Safaricom like this:

1. Have a Safaricom **Paybill**. No paybill yet? Get one from Safaricom first.
2. Go to [developer.safaricom.co.ke](https://developer.safaricom.co.ke) and sign up using
   the phone number that owns the paybill.
3. Click **Go Live**, enter the Paybill number, and confirm with the code Safaricom texts.
4. Safaricom emails the **Passkey**. The **Consumer Key** and **Consumer Secret** are on
   the site under **My Apps**.
5. Paste the four values into the form. Leave `test_mode` on until ready for real money.

Stuck merchants can email `M-PESABusiness@safaricom.co.ke` or call `0722 002 222` and an
agent will set it up and send the passkey.

## How a payment flows

1. At checkout the customer enters their phone number.
2. `authorize` requests a Daraja OAuth token, then sends an **STK Push** (shortcode +
   passkey + timestamp → password, plus the phone and amount).
3. The customer approves with their M-Pesa PIN on their phone.
4. Daraja calls back `POST /mpesa/callback`. `Spree::MpesaCallbacksController` then queries
   Daraja to **independently confirm** the result and completes the payment only when
   Safaricom reports it paid and the amount matches.

Use `test_mode` (default true) with the Daraja sandbox (`shortcode 174379` + the test
passkey) to build without moving real money.

## The callback URL

Safaricom must reach a **public** URL, so the callback host is derived per store from the
order's `storefront_url` (each shop's own domain). 
 For local
testing, expose the dev server with a tunnel (for example `ngrok`) so Safaricom can reach
`/mpesa/callback`; `localhost` is not reachable from Safaricom.

## Security

- **Credentials and phone numbers are filtered from the logs**
  (`config/initializers/filter_parameter_logging.rb`), so the consumer secret, passkey, and
  customer phone never appear in plaintext log output.
- **The callback is verified, not trusted.** A forged or replayed callback cannot complete
  an order: the controller independently queries Daraja and checks the amount before
  marking anything paid, and ignores callbacks for an already-resolved source.
- **Optional rate limiting** on the callback endpoint via `Rack::Attack`
  (`config/initializers/rack_attack.rb`), active in production or when
  `ENABLE_RACK_ATTACK=true`.
- Credentials are stored as Spree preferences. Encrypting them at rest is a planned
  hardening step; until then, protect database access accordingly.

## Development (wiring into spree_starter)

Add to the host app's `Gemfile`. Use a local path during development; switch to git + tag
once published, like the other gems:

```ruby
# development
gem 'spree_mpesa', path: '../spree_mpesa'

# published
gem 'spree_mpesa', git: 'https://github.com/truehostcloud/spree_mpesa.git', tag: 'v0.1.0'
```

Then:

```bash
bundle install
bin/rails g spree_mpesa:install
bin/rails db:migrate
```

## Tests

```bash
bundle exec rspec
bundle exec rubocop
```

`spec/` covers the Daraja client (OAuth, STK Push request shape, response parsing, and the
status query). Payment-method, source, and callback specs run against the Spree test
harness in the host app and are being brought into the gem's own suite. CI runs RuboCop and
RSpec on every push and pull request.
