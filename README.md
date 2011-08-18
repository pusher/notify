# Adding in-app notifications to your Heroku Rails app with Pusher

Applications with social features are often a hive of realtime user activity. Sometimes that activity needs to be directed to specific users so that they can act on it. This tutorial will you show you how to add these in-app notifications to your Rails application quickly and easily using Pusher.

Pusher is designed to make this type of task super easy. There is no significant software to install on your servers, and no need to worry about maintaining extra realtime infrastructure.  

# What we'll build

This tutorial will apply to a theoretical social-networking application that we refer to as 'BookFace'. When a user sends a message to another user who is browsing the site, they will receive a notification that prompts them to view the new message. The source code for the Rails app is available here: [https://github.com/pusher/notify](https://github.com/pusher/notify).

Our very basic application consists of 

* home page with a list of users
* login, registration (using devise)
* profile page
* basic message sending between users

Our message sending functionality is essentially a RESTful resource called `messages`, a database table of the same name (with subject, body, sender_id, recipient_id, created_at). It also includes a couple of views that allow a user to send a message to another user, and to view those they have been sent. 

## Getting set up locally

Once you've checked out the code for the app, you'll need to get it running locally, which should be fairly trivial.

    bundle install
    bundle exec rake db:create
    bundle exec rake db:migrate
    script/rails s

## Adding the Pusher Heroku add-on

At this point we will  add the Pusher functionality via the Heroku Addon. The first thing to do is to make sure this example has an associated Heroku app (use `heroku create` to do this).

Now visit <http://devcenter.heroku.com/articles/pusher> and follow the instructions (everything up to the _Verifying your set up_ section) for adding the Pusher Heroku add-on. Make sure you have also copied the development access keys for testing locally (add them to `./config/environments/development.rb`).

Finally, to send messages into Pusher from this Rails app, we're using the official [pusher-gem](https://github.com/pusher/pusher-gem) library ([rdocs here](http://rdoc.info/github/pusher/pusher-gem/master/frames)), which we add to our Gemfile.

## Adding a connection on each page

To receive events on the client side, we'll be using the official [Pusher Javascript client library](http://pusher.com/docs/client_libraries#js). There are some more tips on getting started with this in our [JavaScript Quick Start Guide](http://pusher.com/docs/javascript_quick_start) too.

Edit `app/views/layouts/application.html.erb` and add the following within the `<head>`:

    <script src="http://ajax.googleapis.com/ajax/libs/jquery/1.4.2/jquery.min.js"></script>
    <script src="http://js.pusherapp.com/1.9/pusher.min.js"></script>

## Subscribing to a private channel for that user

When a page loads, we want the user to automatically subscribe to their own private Pusher channel which the server can then send notifications to. Pusher has a powerful authentication system you can read about here: [Authenticating users](http://pusher.com/docs/authenticating_users). 

On the client side we make a subscription to a channel named after the user's ID. Also note that you will need to replace `APP_KEY` with the PUBLIC_KEY of your app. This can be found in your Pusher dashboard (available via by clicking on the addon from your Heroku account). 

We use a simple but effective method of injecting the user ID into the javascript below by using the ERB snippet `<%= current_user.id %>`. Paste the following into your `<head>` just after pusher.js is included.

    <script type="text/javascript" charset="utf-8">
      $(function() {
        var pusher = new Pusher('fa7c1e955481731b1662'); // Replace with your app key
        var channel = pusher.subscribe('private-'+<%= current_user.id %>);

        // Some useful debug msgs
        pusher.connection.bind('connecting', function() {
          $('div#status').text('Connecting to Pusher...');
        });
        pusher.connection.bind('connected', function() {
          $('div#status').text('Connected to Pusher!');
        });
        pusher.connection.bind('failed', function() {
          $('div#status').text('Connection to Pusher failed :(');
        });
        channel.bind('subscription_error', function(status) {
          $('div#status').text('Pusher subscription_error');
        });
      });
    </script>

Now whenever the page loads, the Pusher javascript library will make an AJAX POST request to the url `/pusher/auth` of your app (this can be changed if desired). This action authorises the user and returns a signed token that is used to connect securely to Pusher.

## Creating our authentication endpoint

This is relatively trivial, we'll simply create a new controller called `pusher_controller.rb`:

    class PusherController < ApplicationController
      protect_from_forgery :except => :auth # stop rails CSRF protection for this action

      def auth
        if current_user
          response = Pusher[params[:channel_name]].authenticate(params[:socket_id])
          render :json => response
        else
          render :text => "Not authorized", :status => '403'
        end
      end
    end

Then also add in the following to your `config/routes.rb`:

    post 'pusher/auth'

Fire up the app with `script/rails s` and visit <http://localhost:3000/>. You should see the 'Pusher connected!' status messages.

## Sending notifications

Now that the HTML view is hooked up to our Pusher channels, we can concentrate on sending some messages to them. In BookFace we send these `events` to a user who has received a message. 

Doing this with Pusher is super easy. First we add the following line to   `app/controllers/messages_controller.rb` to `trigger` a `new_message` after one is successfully saved:

    Pusher['private-'+params[:message][:recipient_id]].trigger('new_message', {:from => current_user.name, :subject => message.subject})

This is sent to a private channel based on the recipient's user id.

On the client side we now need to bind to this event and display something when it is triggered. Open up `app/views/layouts/application.html.erb` again and add the following after the Pusher connection code inside your `<script>` tag:

    channel.bind('new_message', function(data) {
      msg = data.from + ' has sent you message: ' + data.subject;
      dom_notify(msg);
    });
    
    function dom_notify(msg) {
      $('#notify').text(msg);
      $('#notify').fadeIn();
      setTimeout(function() {
        $('#notify').fadeOut
        ();
      }, 2000);
    }

# Test it out!

Now load up <http://localhost:3000/> in __two different browsers__ so you can pretend to be two users on the site. Register as a BookFace user in each and then send a new message from one to the other. When the message is sent you should get a notification in the other!

# Improving the notifications

To get the user's attention even if they're in another window, there are a few other types of notifications we can trigger.

## Change the &lt;title&gt; of the page

In our example, we will change the title of the window when a message is received to "BookFace (1 unread message)". To do this we use a little `<title>` bar changing jQuery plugin ([original site](http://heyman.info/2010/sep/30/jquery-title-alert/)) to do this. This involves adding the following to the `<head>`:

    <script src="/javascripts/jquery.titlealert.js"></script>

Then add a new `title_notify()` function to the javascript:

    function title_notify(msg) {
      $.titleAlert(msg);
    }

Also add `title_notify(msg);` after `dom_notify(msg);` when the new_message event is triggered.

Now send another message and watch the title bar flash!

## Going further with HTML5 Notifications

For even more HTML5 fun, you can add support for the Webkit Notifications API. Rather than go into it in this tutorial, we have done a proof of concept version in our app for those who are curious.



     

