$(function () {

  var $tweetForm = $("#tweet_form");
  var $textarea = $tweetForm.find("textarea");
  var $flashMessage = $(".flash-message")
  var $tweets = $(".tweets");
  var $refreshClock = $("#refresh_clock");

  var latestTweetId;

  var rateLimitSeconds = 60 * 15; // 15 minutes
  var requestsPerInterval = 15;
  var remainingSeconds = rateLimitSeconds;
  var remainingRequests = requestsPerInterval;

  ////////////// sign in //////////////

  // Redirect and include the query string required by the server.
  // After authentication, the server will use these query parameters
  // to redirect the user back to the url we've specified in the config file.
  // Note that the screen_name parameter serves two purposes:
  // 1. as a key for storing the redirect url
  // 2. forces the twitter OAuth to prepopulate the login screen with the username.
  $('#sign-in').on('click', function () {
    var nickname = $('#nickname-key').val();
    var url =  window.location.href
    url += (url[url.length - 1] == "/") ? "tweet" : "/tweet"
    window.location = "http://localhost:3000/auth/twitter?screen_name=" + nickname + "&url=" + url
  });

  ////////////// tweet form //////////////

  var handleSubmit = function (e) {
    e.preventDefault();

    var tweet = $textarea.val();
    if (tweet.length == 0) {
      return;
    }

    $.ajax({
      type: "POST",
      url: "/tweet",
      data: { "tweet": $textarea.val() },
      success: tweetSuccess,
      error: tweetError,
      dataType: "json"
    });
  };

  var tweetSuccess = function (data, textStatus, jqXHR) {
    // console.log(arguments);
    $textarea.val("").focus();
    flashMessage(true);
  };

  var tweetError = function (jqXHR, textStatus, errorThrown) {
    // console.log(arguments);
    flashMessage(false);
  };

  var flashMessage = function (success) {
    var state = success ? "success" : "error"
    var text = success ? "tweeted!" : "error!  did not successfully tweet!"
    $flashMessage.addClass(state).text(text);
    setTimeout(clearFlashMessage, 5000);
  };

  var clearFlashMessage = function () {
    $flashMessage.text("").removeClass("success error")
  };

  $tweetForm.on("submit", handleSubmit);


  ////////////// timeline //////////////

  var getTimeline = function (params) {
    var params = params || {};
    var timelineType = params.type || "home";
    delete params.type
    var url = "/" + (params.url || "timeline/" + timelineType);
    delete params.url

    $.ajax({
      type: "GET",
      url: url,
      data: params,
      success: timelineSuccess,
      error: timelineError,
      dataType: "json"
    });
    startCountdown();
  };

  var timelineSuccess = function (data, textStatus, jqXHR) {
    console.log(data);
    window.data = data;
    if (typeof data.error == 'undefined' && data.length > 0) {
      latestTweetId = data[0].id_str;
      renderTweets(formatTweets(data));
    }
    else if (data.error == "Twitter::Error::TooManyRequests") {
      console.log('too many requests.  TODO: handle this.')
    }
    remainingRequests--;
  }

  var timelineError = function (jqXHR, textStatus, errorThrown) {
    console.log("timelineError", arguments);
  }

  var formatTweets = function (data) {
    return $.map(data, function format(tweet, i) {
      return {
        id: tweet.id_str,
        text: createLinks(tweet.text),
        user: {
          img: tweet.user.profile_image_url,
          name: tweet.user.name,
          nickname: tweet.user.screen_name
        }
      }
    });
  }

  var createLinks = function (str) {
    var regex = /(https?:\/\/[^\s]*)/g
    return str.replace(regex, "<a href='$1' target='_blank'>$1</a>")
  }

  var renderTweets = function (tweets) {
    var html = $.map(tweets, function (tweet, i) {
      return createTweetHtml(tweet)
    });
    $tweets.prepend(html.join(''));
  }

  var createTweetHtml = function (tweet) {
    var html =  '<li class="tweet" data-id="' + tweet.id + '">';
        html +=   '<div class="col-1">';
        html +=     '<img class="user profile-image" height="48px" width="48px" src="' + tweet.user.img + '" alt="" />';
        html +=   '</div>';
        html +=   '<div class="col-2">';
        html +=     '<span class="user name">' + tweet.user.name + '</span>&nbsp;';
        html +=     '<span class="user nickname">@' + tweet.user.nickname + '</span>';
        html +=     '<span class="tweet-text">' + tweet.text + '</span>';
        html +=   '</div>';
        html += '</li>';
    return html;
  }

  var startCountdown = function (id) {
    // console.log(remainingRequests, remainingSeconds)
    var seconds;
    if (remainingRequests !== 0) {
      seconds = Math.ceil(remainingSeconds/remainingRequests);
    }
    else {
      seconds = remainingSeconds;
    }
    // console.log("countdown seconds", seconds);
    setTimeout(function countdown () { // the cool thing about naming this function is that "this" does not change and become window.
      seconds--;
      $refreshClock.text(seconds)
      if (seconds == 0) {
        getTimeline({"since_id": latestTweetId});
      }
      else {
        setTimeout(countdown, 1000);
      }
    }, 1000);
  }

  var manageRateLimit = function () {
    // console.log("manage rate limit", remainingRequests, requestsPerInterval, remainingSeconds, rateLimitSeconds )
    if (remainingSeconds == 0) {
      remainingRequests = requestsPerInterval;
      remainingSeconds = rateLimitSeconds;
    } else {
      remainingSeconds--;
    }
  }


  ////////////// start me up ///////////////

  if (location.pathname == "/tweet") {
    setInterval(manageRateLimit, 1000);
    getTimeline();
  }

});