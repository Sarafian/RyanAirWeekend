# Ryan Air Weekends 

| Branch | Status
| ---------- | ---------
| **master** | ![masterstatus](https://asarafian.visualstudio.com/_apis/public/build/definitions/d49ceb99-ba17-40dd-beb5-01203465975d/20/badge)
| **develop** | ![developstatus](https://asarafian.visualstudio.com/_apis/public/build/definitions/d49ceb99-ba17-40dd-beb5-01203465975d/19/badge)


## Repository in progress
The repository is ![](https://img.shields.io/badge/Important-In%20Progress-orange.svg). Items remaining

- Improve the web site
  - Improve the text in each page
  - Add footer and general information
  - Create a blog post in [sarafian.github.io](https://sarafian.github.io/)
  - Layout
- Add feedback link
- Fix some share buttons
- Optimize performance. Overcome the 30 minutes execution time restriction by [Visual Studio Team Services](https://visualstudio.com/ "Visual Studio Team Services") hosted agents.

## Introduction

I like short city weekend trips. Often I travel with [Ryan Air](https://www.ryanair.com/). Choosing a destination depends on two important questions:

- Is it possible to visit within a weekend? That means 
  - Depart to destination on Friday evening after work or arrive at destination on Saturday morning.
  - Depart from destination on Sunday evening or arrive home on Monday early morning before work.
- Price. A weekend before or after doesn't really matter as long as the price is right.

This repository is to automate the generation of [Ryan Air weekend](https://sarafian.github.io/RyanAirWeekend).

## Dependencies

This repository depends on my two PowerShell modules. 

- My PowerShell module [MarkdownPS](https://www.powershellgallery.com/packages/MarkdownPS/) makes it easy to render markdown content.
- My PowerShell module [RyanAirPS](https://www.powershellgallery.com/packages/RyanAirPS/) queries the RyanAir API. (*Not Published yet*)

As with my [blog](https://sarafian.github.io/) the site is also powered by [Hugo](https://gohugo.io/) using a simplified version of [Hugo Future Imperfect](http://themes.gohugo.io/future-imperfect/) theme. Actually the theme is derived from my already modified version that powers my own [blog](https://sarafian.github.io/).

Badges are powered by [shields.io](http://shields.io/)

## Execution order

1. Parse the RyanAir open api and store json files in a temp folder.
1. Process the json files and generate markdown files. Files can be generated in two formats
  - Hugo suitable with front matter
  - Node package [MarkServ](https://www.npmjs.com/package/markserv).
1. Generate static html files using Hugo
1. Update `gh-pages` with new files

The non Hugo compatible files were the original implementation. They are now used for debugging with my custom MarkServ windows service as explained [here](https://sarafian.github.io/post/simple markdown web server for windows/).

## References

- MarkdownPS
  - [PowerShell Gallery](https://www.powershellgallery.com/packages/MarkdownPS/) 
  - [Github](github.com/Sarafian/MarkdownPS) 
  - [Relevant articles](https://sarafian.github.io/post/markdownps/markdownps/)
- RyanAirPS
  - [PowerShell Gallery](https://www.powershellgallery.com/packages/RyanAirPS/) ![](https://img.shields.io/badge/Important-Not%20yet%20published-rewd.svg)
  - [Github](github.com/Sarafian/RyanAirPS)
- Hugo 
  - [Hugo](https://gohugo.io/) 
  - Original [Hugo Future Imperfect](http://themes.gohugo.io/future-imperfect/) theme
  - [Build and publish Hugo from Visual Studio services](https://sarafian.github.io/post/hugo%20build%20in%20visual%20studio%20services/)
- MarkServ
  - Node package [MarkServ](https://www.npmjs.com/package/markserv) 
  - [Simple markdown web server for windows](https://sarafian.github.io/post/simple markdown web server for windows/)
- Badges
  - [shields.io](http://shields.io/)
  - [shields.io badges with PowerShell MarkdownPS](https://sarafian.github.io/post/markdownps/shields.io badges with powershell markdownps/)