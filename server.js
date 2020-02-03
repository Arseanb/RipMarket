const http = require("http")
const fs = require("fs")
const port = 1414
const key = "1234"

function zero(value) {
    return value <= 9 ? "0" : ""
}

function getTime(type) {
    let full = new Date()

    let day = full.getDate()
    let month = full.getMonth() + 1
    let year = full.getFullYear()

    let hour = full.getHours()
    let minute = full.getMinutes()
    let second = full.getSeconds()

    if (type == "full") {
        return zero(day) + day + "." + zero(month) + month + "." + year + " " + zero(hour) + hour + ":" + zero(minute) + minute + ":" + zero(second) + second
    } else if (type == "log") {
        return "[" + zero(hour) + hour + ":" + zero(minute) + minute + ":" + zero(second) + second + "] "
    } else if (type == "fs") {
        return zero(day) + day + "." + zero(month) + month + "." + year
    }
}

function checkDir(dir) {
    if (!fs.existsSync(dir)) {
        fs.mkdirSync(dir)
    }
}

function log(data, ...args) {
    let path = "logs/"
    data = getTime("log") + data
    checkDir("logs/")
    console.log(data)

    try {
        if (args.length >= 1) {
            for (let i = 0; i < args.length; i++) {
                checkDir(path + args[i])
                path = path +  args[i] + "/"
            }
        }
    } catch(err) {
        console.log(err)
    }

    fs.appendFile(path + getTime("fs") + ".log", data + "\n", function(err) {
        if (err) {
            console.log(err)
        }
    })
}

function readUser(name) {
    let data = fs.readFileSync("users/" + name + ".txt", "utf8")

    if (data != "") {
        try {
            return JSON.parse(data)
        } catch(err) {
            log("Bad user " + name + ", unable to parse!")
            return false
        }
    }
}

function readFeedbacks() {
    if (fs.existsSync("feedbacks.txt")) {
        let data = fs.readFileSync("feedbacks.txt", "utf8")

        if (data != "") {
            try {
                return JSON.parse(data)
            } catch(err) {
                log("Unable to parse feedbacks, err: " + err)
                return false
            }
        } else {
            return false
        }
    } else {
        return false
    }
}

function writeFeedback(name, feedback) {
    let feedbacks = readFeedbacks()

    if (feedbacks) {
        feedbacks[Object.keys(feedbacks).length + 1] = {feedback: feedback, name: name}
    } else {
        feedbacks = {
            [1]: {feedback: feedback, name: name}
        }
    }

    if (feedbacks) {
        fs.writeFileSync("feedbacks.txt", JSON.stringify(feedbacks))
        let userdata = {feedback: feedback}
        updateUser(name, userdata)
    }
}

function updateUser(name, data) {
    checkDir("users/")
    let userPath = "users/" + name + ".txt"
    let merged

    if (fs.existsSync(userPath)) {
        let userdata = readUser(name)
        merged = Object.assign(userdata, data)
    }

    try {
        fs.writeFileSync(userPath, JSON.stringify(merged || data))
    } catch(err) {
        log("Unable to stringify JSON, err: " + err)
        return false
    }

    return true
}

function reg(name, server) {
    log("Registration user " + name)
    let time = getTime("full")
    let user = {
        balance: {
            [server]: 0
        },
        transactions: 0,
        lastLogin: time,
        regTime: time,
        feedback: false,
        banned: false,
        eula: false
    }
    
    if (updateUser(name, user)) {
        return user
    } else {
        return false
    }
}

function login(name, server) {
    let path = "users/" + name + ".txt"

    if (fs.existsSync(path)) {
        log("User login " + name)
        let userdata = readUser(name)

        if (userdata) {
            if (!userdata.balance[server]) {
                userdata.balance[server] = 0
            }

            userdata.lastLogin = getTime("full")
            if (updateUser(name, userdata)) {
                return userdata
            } else {
                return false
            }
        } else {
            return false
        }
    } else {
        if (reg(name, server)) {
            return login(name, server)
        } else {
            return false
        }
    }
}

function writeHead(code, response) {
    response.writeHead(code, {"Content-Type": "text/html; charset=utf-8"})
}

function responseHandler(uri, response) {
    log("URI " + uri)
    let userdata

    try {
        userdata = JSON.parse(uri)
    } catch(err) {
        log("Unable to parse JSON, err: " + err)
        response.write('{"code":422, "message":"Unable to parse JSON, err: ' + err + '"}')
    }

    if (userdata) {
        if (userdata.key && userdata.key == key) {
            if (userdata.log) {
                if (userdata.log.path) {
                    try {
                        log(userdata.log.data, ...userdata.log.path)
                    } catch(err) {
                        log(err)
                    }
                } else {
                    log(userdata.log.data)
                }
            }

            if (userdata.method) {
                if (userdata.method == "test") {
                    response.write('{"code":200, "message":"OK"}')
                } else {
                    if (userdata.name) {
                        if (userdata.server) {
                            if (userdata.method == "login") {
                                let success = login(userdata.name, userdata.server)
                                
                                if (success) {
                                    let feedbacks = readFeedbacks()

                                    let responseMessage = {
                                        code: 200,
                                        message: "Login successfully",
                                        userdata: success,
                                        feedbacks: readFeedbacks()
                                    }
                                    response.write(JSON.stringify(responseMessage))
                                } else {
                                    response.write(('{"code" = 500, message = "Unable to login, unexpected error"}'))
                                }
                            } else if (userdata.method == "merge") {
                                if (userdata.toMerge) {
                                    if (updateUser(userdata.name, userdata.toMerge)) {
                                        response.write('{"code":200, "message":"Merged successfully"}')
                                    } else {
                                        response.write('{"code":500, "message":"Unable to merge, unexpected error"}')
                                    }
                                } else {
                                    response.write('{"code":422, "message":"toMerge is undefined"}')
                                }
                            } else if (userdata.method == "feedback") {
                                if (userdata.feedback) {
                                    writeFeedback(userdata.name, userdata.feedback)
                                    response.write('{"code":200, "message":"Review submitted successfully"}')
                                } else {
                                    response.write('{"code":422, "message":"Bad feedback"}')
                                }
                            } else {
                                response.write('{"code":422, "message":"Bad method"}')
                            }
                        } else {
                            response.write('{"code":422, "message":"Bad server name"}')
                        }
                    } else {
                        response.write('{"code":422, "message":"Bad username"}')
                    }
                }
            } else {
                response.write('{"code":422, "message":"Bad method"}')
            }
        } else {
            response.write('{"code":422, "message":"Bad key"}')
        }
    }
}

function requestHandler(request, response) {
    log("Request from IP " + request.connection.remoteAddress)
    writeHead(200, response)

    if (request.url != "/favicon.ico" && request.url != "/") {
        let uri

        try {
            uri = decodeURIComponent(request.url)
        } catch(err) {
            response.end('{"code":422, "message":"Unable to parse URI, err: "' + err + '"}')
            log("Unable to parse URI, err: " + err)
        }

        if (uri) {
            responseHandler(uri.replace("/", ""), response)
            response.end()
        }
    } else if (request.url != "/favicon.ico") {
        response.end("R.I.P")
    } else {
        response.end()
    }
}

function backup() {
    if (!fs.existsSync("backups/")) {
        fs.mkdirSync("backups/")
    }
    let backupPath = "backups/" + getTime("fs") + "/"

    if (!fs.existsSync(backupPath) && fs.existsSync("users/")) {
        log("Doing backup...")
        fs.mkdirSync(backupPath)
        let files = fs.readdirSync("users/")
        let backupPathUsers = backupPath + "users/"

        if (!fs.existsSync(backupPathUsers)) {
            fs.mkdirSync(backupPathUsers)
        }

        if (files.length >= 0) {
            for (let i = 0; i < files.length; i++) {
                fs.copyFileSync("users/" + files[i], backupPathUsers + files[i])
            }
        }

        if (fs.existsSync("feedbacks.txt")) {
            fs.copyFileSync("feedbacks.txt", backupPath + "feedbacks.txt")
        }
        log("Backup complete!")
    }
}

const server = http.createServer(requestHandler)
server.listen(port, (err) => {
    if (err) {
        log("Something bad happened " + err)
        process.exit()
    } else {
        log("RipMarket started on port " + port + "!")
        backup()
        setInterval(backup, 300000)
    }
})
