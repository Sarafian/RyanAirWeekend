# Ryan Air Weekends 

| Branch | Status
| ---------- | ---------
| **master** | ![masterstatus](https://asarafian.visualstudio.com/_apis/public/build/definitions/d49ceb99-ba17-40dd-beb5-01203465975d/20/badge)
| **develop** | ![developstatus](https://asarafian.visualstudio.com/_apis/public/build/definitions/d49ceb99-ba17-40dd-beb5-01203465975d/19/badge)


## Repository in progress
The repository code needs still some improvements. Items remaining

- Add feedback link
- Fix some share buttons

## Introduction

I like short city weekend trips. Often I travel with [Ryan Air](https://www.ryanair.com/). Choosing a destination depends on two important questions:

- Is it possible to visit within a weekend? That means 
  - Depart to destination on Friday evening after work or arrive at destination on Saturday morning.
  - Depart from destination on Sunday evening or arrive home on Monday early morning before work.
- Price. A weekend before or after doesn't really matter as long as the price is right.

This repository powers [Ryan Air weekend](https://sarafian.github.io/RyanAirWeekend).

## Dependencies

This repository depends on my two PowerShell modules. 

- [MarkdownPS](https://www.powershellgallery.com/packages/MarkdownPS/) which makes easy to render markdown content.
- [RyanAirPS](https://www.powershellgallery.com/packages/RyanAirPS/) which queries the RyanAir API. 
It turned out that PowerShell was too slow for my requirements, so the time consuming functionality provided by [RyanAirPS](https://www.powershellgallery.com/packages/RyanAirPS/) was ported to pure .NET. 

As with my [blog](https://sarafian.github.io/) the site is also powered by [Hugo](https://gohugo.io/) using a simplified version of [Hugo Future Imperfect](http://themes.gohugo.io/future-imperfect/) theme. 
Actually the theme is derived from my already modified version that powers my own [blog](https://sarafian.github.io/).

Badges are powered by [shields.io](http://shields.io/)

## Execution order

1. Build the [ExportJSON](VSS/ExportJson/ExportJson.sln) project.
1. Figure out all airport code that RyanAir flies from and the schedule for each destination. [![RyanAirPS](https://img.shields.io/badge/Powered%20by-RyanAirPS-blue.svg)](https://www.powershellgallery.com/packages/RyanAirPS/)
1. Parse the RyanAir open api and store json files in a temp folder. 
1. Process the json files and generate markdown files. Files can be generated in two formats.  [![MarkdownPS](https://img.shields.io/badge/Powered%20by-MarkdownPS-blue.svg)](https://www.powershellgallery.com/packages/MarkdownPS/)
  - Hugo suitable with front matter
  - Node package [MarkServ](https://www.npmjs.com/package/markserv).
1. Generate static html. Powered by 
1. Update `gh-pages` with new files

The non Hugo compatible files were the original implementation. They are now used for debugging with my custom MarkServ windows service as explained [here](https://sarafian.github.io/post/simple markdown web server for windows/).

## References

- MarkdownPS
  - [PowerShell Gallery](https://www.powershellgallery.com/packages/MarkdownPS/) 
  - [Github](github.com/Sarafian/MarkdownPS) 
  - [Relevant articles](https://sarafian.github.io/post/markdownps/markdownps/)
- RyanAirPS
  - [PowerShell Gallery](https://www.powershellgallery.com/packages/RyanAirPS/)
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