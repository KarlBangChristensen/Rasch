library(shiny)

shinyUI(pageWithSidebar(
  headerPanel("Rasch model"),
    sidebarPanel(
      fileInput('file1', 'Choose CSV File',
                accept=c('text/csv',
                         'text/comma-separated-values,text/plain',
                         '.csv')),
      tags$hr(),
      checkboxInput('header', 'Header', TRUE),
      radioButtons('sep', 'Separator',
                   c(Comma=',',
                     Semicolon=';',
                     Tab='\t'),
                   ','),
      radioButtons('quote', 'Quote',
                   c(None='',
                     'Double Quote'='"',
                     'Single Quote'="'"),
                   '"'),
    radioButtons("Modeltype", "Model type:",
                 list("Dichtomous Rasch model" = "RM",
                      "Polytomous Rasch model" = "residuals")),
    checkboxInput(inputId = "ICC",
                  label = strong("Plot Item Characteristic Curves"),
                  value = FALSE)
  ),

  mainPanel(
      #plotOutput(outputId = "main_plot", height="600px", width="800px")
  ))
)
