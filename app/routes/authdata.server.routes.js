"use strict";

/**
 * Module dependencies.
 */
var users = require("../../app/controllers/users"),
  authdata = require("../../app/controllers/authdata");

module.exports = function(app) {
  app.route("/authdata:parameters").get(users.requiresLogin, authdata.read);
  app.param("parameters", authdata.getData);
};
