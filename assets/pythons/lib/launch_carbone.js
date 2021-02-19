'use strict';

// returns the value of `num1`
//console.log("ARgumentos")
//console.log(process.argv);

var myArgs = process.argv.slice(2);
console.log('myArgs: ', myArgs);
var pathRoot = myArgs[0]
console.log('pathRoot: ', pathRoot);
var mId = myArgs[1]
console.log('mId: ', mId);
var mName = myArgs[2]
console.log('mName: ', mName);
var use_mName = myArgs[3]
console.log('use_mName: ', use_mName);
var periodId = myArgs[4]
console.log('periodId: ', periodId);
var period2Id = myArgs[5]
console.log('period2Id: ', period2Id);
var lim11 = myArgs[6]
console.log('lim11: ', lim11);
var lim12 = myArgs[7]
console.log('lim12: ', lim12);
var lim21 = myArgs[8]
console.log('lim21: ', lim21);
var lim22 = myArgs[9]
console.log('lim22: ', lim22);

const fs = require('fs');
const carbone = require('carbone');

let rawdata = fs.readFileSync(pathRoot + '/doc/issues.json');
let data = JSON.parse(rawdata);

var options = {
    variableStr: '{#mId = ' + mId +
            '},{#period = ' + periodId +
            '},{#nextPeriod = ' + period2Id +
            '},{#lim11 = ' + lim11 +
            '},{#lim12 = ' + lim12 +
            '},{#lim21 = ' + lim21 +
            '},{#lim22 = ' + lim22 +
            '}'
};
console.log('options: ', options);

if (use_mName == "0") {

    carbone.render(pathRoot + '/templates/issues_template.odt', data, options, function (err, result) {
        if (err)
            return console.log(err);
        fs.writeFileSync(pathRoot + '/doc/pr' + mName + '.odt', result);
    });

    carbone.render(pathRoot + '/templates/issues_template.ods', data, options, function (err, result) {
        if (err)
            return console.log(err);
        fs.writeFileSync(pathRoot + '/doc/pr' + mName + '.ods', result);
    });
} else {
    carbone.render(pathRoot + '/templates/issues_byperson_template.odt', data, options, function (err, result) {
        if (err)
            return console.log(err);
        fs.writeFileSync(pathRoot + '/doc/' + mName + '.odt', result);
    });

    carbone.render(pathRoot + '/templates/issues_byperson_template.ods', data, options, function (err, result) {
        if (err)
            return console.log(err);
        fs.writeFileSync(pathRoot + '/doc/' + mName + '.ods', result);
    });
    /*
    var tmpfile = new File(pathRoot + '/templates/prev_byperson_template.ods');
    if (tmpfile.exists()) {
        carbone.render(pathRoot + '/templates/prev_byperson_template.ods', data, options, function (err, result) {
            if (err)
                return console.log(err);
            fs.writeFileSync(pathRoot + '/doc/' + mName + '_prev.ods', result);
        });
    }*/
}