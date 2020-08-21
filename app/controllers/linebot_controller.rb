class LinebotController < ApplicationController
  require "line/bot" # gem "line-bot-api"

  # callbackアクションのCSRFトークン認証を無効
  protect_from_forgery :except => [:callback]

  def client
    @client ||= Line::Bot::Client.new { |config|
      config.channel_secret = ENV["LINE_CHANNEL_SECRET"]
      config.channel_token = ENV["LINE_CHANNEL_TOKEN"]
    }
  end

  def callback
    body = request.body.read

    signature = request.env["HTTP_X_LINE_SIGNATURE"]
    unless client.validate_signature(body, signature)
      error 400 do
        "Bad Request"
      end
    end

    events = client.parse_events_from(body)

    events.each { |event|
      case event
      when Line::Bot::Event::Message

        #　送信した人の名前を取得
        userId = event["source"]["userId"]
        response = client.get_profile(userId)
        case response
        when Net::HTTPSuccess then
          contact = JSON.parse(response.body)
          userName = contact['displayName'] + "さん"
        else
          userName = "誰か知らんけど"
        end

        case event.type
        when Line::Bot::Event::MessageType::Text
          message = {
              type: "text",
              text: userName + "\n" + event.message["text"] + "!"
          }
          client.reply_message(event["replyToken"], message)
        when Line::Bot::Event::MessageType::Location
          message = {
              type: "location",
              title: "あなたはここにいますか？",
              address: event.message["address"],
              latitude: event.message["latitude"],
              longitude: event.message["longitude"]
          }
          client.reply_message(event["replyToken"], message)
        end
      end
    }

    head :ok
  end
end