.pragma library

var sortOptions = ["relevance", "random", "date_added", "views", "favorites", "toplist"]
var sortLabels  = ["RELEV",     "RAND",   "NEW",        "VIEWS", "FAV",       "TOP"]

var prefixes = ["@wh", "@a", "@r", "@wpe", "@gif", "@img", "@wc", "@y", "@kc", "@sb", "@da", "@as", "#"]

// Static color per prefix — used for chip and placeholder styling.
var prefixColors = {
    "@wh": "#25e1ed",
    "@a":  "#fcec0c",
    "@r":  "#ea00d9",
    "@wpe":"#39c4b6",
    "@gif":"#39ff14",
    "@img":"#25e1ed",
    "@wc": "#ff9800",
    "@y":  "#ff66aa",
    "@kc": "#a8ff60",
    "@sb": "#66c0ff",
    "@da": "#05cc47",
    "@as": "#13aff0",
    "#":   "#f78b04"
}
