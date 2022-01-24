var fs = require('fs'),
    http = require('http');

http.createServer(function (req, res) {
  req.url = req.url == '/' ? '/index.html' : req.url;

  fs.readFile(__dirname + req.url, function (err, data) {

  

    console.log(`---> a requset has arrived ${getCurrentTime()}`);    

    if (err) {
      res.writeHead(404);
      res.end(JSON.stringify(err));
      return;
    }


    res.writeHead(200);
    res.end(data);
  });
}).listen(8080);

function getCurrentTime() { 
  let date_ob = new Date();

  let date = ("0" + date_ob.getDate()).slice(-2);
  let month = ("0" + (date_ob.getMonth() + 1)).slice(-2);
  let year = date_ob.getFullYear();
  let hours = date_ob.getHours();
  let minutes = date_ob.getMinutes();
  let seconds = date_ob.getSeconds();
  let currentTime = year + "-" + month + "-" + date + " " + hours + ":" + minutes + ":" + seconds;
  return currentTime;
}
console.log("nodejs is listening on port 8080");