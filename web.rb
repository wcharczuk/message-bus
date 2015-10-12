require 'rubygems'
require 'base64'
require 'openssl'
require 'sinatra'
require 'json'
require 'sinatra/json'
require 'rest-client'

SHARED_SECRET = ENV['SHARED_SECRET']
SLACK_WEBHOOK = ENV['SLACK_WEBHOOK']

helpers do
	# Compare the computed HMAC digest based on the shared secret and the request contents
	# to the reported HMAC in the headers
	def verify_webhook(data, hmac_header)
		digest  = OpenSSL::Digest.new('sha256')
		calculated_hmac = Base64.encode64(OpenSSL::HMAC.digest(digest, SHARED_SECRET, data)).strip
		calculated_hmac == hmac_header
	end
end

get '/' do
	json :status => "ok"
end

# Respond to HTTP POST requests sent to this web service
post '/shopper' do
	request.body.rewind
	body_data = request.body.read

	verified = verify_webhook(body_data, env["HTTP_X_SHOPIFY_HMAC_SHA256"])

	if !verified
		status 400
		json :status => "invalid_request"

	end

	parsed_data = JSON.parse(body_data)

	returned_data = { :text => "New Shopper Signup!\n" }
	returned_data[:username] = "Shopify (New Customer)"
	returned_data[:icon_url] = "https://support.wombat.co/hc/en-us/article_attachments/200579685/shopify-expert-web-designer.jpg"
	returned_data[:text] = returned_data[:text] << "<https://kissandwear.com/admin/customers/#{parsed_data['id']}|#{parsed_data['email']}> #{parsed_data['first_name']} #{parsed_data['last_name']}"

	body_json = JSON.dump returned_data

	RestClient.post SLACK_WEBHOOK, body_json, :content_type => :json, :accept => :json

	json :status => "ok"
end

# Respond to HTTP POST requests sent to this web service
post '/order' do
	request.body.rewind
	body_data = request.body.read

	verified = verify_webhook(body_data, env["HTTP_X_SHOPIFY_HMAC_SHA256"])

	if !verified
		status 400
		json :status => "invalid_request"
	end

	parsed_data = JSON.parse(body_data)

	returned_data = { :text => ":moneybag: New Sale!\n" }
	returned_data[:username] = "Shopify (Sale)"
	returned_data[:icon_url] = "https://support.wombat.co/hc/en-us/article_attachments/200579685/shopify-expert-web-designer.jpg"
	returned_data[:text] = returned_data[:text] << "$<https://kissandwear.com/admin/orders/#{parsed_data['id']}|#{parsed_data['total_price']}> for <http://kissandwear.com/admin/customers/#{parsed_data['customer']['id']}|#{parsed_data['customer']['email']}>"

	body_json = JSON.dump returned_data

	RestClient.post SLACK_WEBHOOK, body_json, :content_type => :json, :accept => :json

	json :status => "ok"
end