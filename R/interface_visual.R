#' Add a visual parameter box for dot plots
#'
#' Create a visual parameter box for row- or column-based dot plots, i.e., where each feature or sample is a point.
#'
#' @param x A DataFrame with one row, containing the parameter choices for the current plot.
#' @param select_info A list of character vectors named \code{row} and \code{column} which specifies the names of panels available for transmitting single selections on the rows/columns.
#' @param se A \linkS4class{SummarizedExperiment} object after running \code{\link{.cacheCommonInfo}}.
#'
#' @return
#' A HTML tag object containing a \code{\link{collapseBox}} with visual parameters for row- or column-based plots.
#'
#' @details
#' Column-based plots can be coloured by nothing, by column metadata, by the expression of a single feature or by the identity of a single sample.
#' This function creates a collapsible box that contains all of these options, initialized with the choices in \code{memory}.
#' The box will also contain options for font size, point size and opacity, and legend placement.
#'
#' Each option, once selected, yields a further subset of nested options.
#' For example, choosing to colour by column metadata will open up a \code{selectInput} to specify the metadata field to use.
#' Choosing to colour by feature name will open up a \code{selectizeInput}.
#' However, the values are filled on the server-side, rather than being sent to the client; this avoids long start times during re-rendering.
#'
#' Note that some options will be disabled depending on the nature of the input, namely:
#' \itemize{
#' \item If there are no column metadata fields, users will not be allowed to colour by column metadata, obviously.
#' \item If there are no features, users cannot colour by features.
#' \item If there are no categorical column metadata fields, users will not be allowed to view the faceting options.
#' }
#'
#' The same logic applies for row-based plots where we swap features with samples (i.e., coloring by feature will highlight a single feature, while coloring by sample will color by the expression of all features in that sample).
#' Similarly, the row metadata is used in place of the column metadata.
#'
#' @author Aaron Lun
#' @seealso
#' \code{\link{.defineInterface}}, where this function is typically called.
#'
#' @importFrom shiny radioButtons tagList selectInput selectizeInput checkboxGroupInput
#' @importFrom colourpicker colourInput
#' @importFrom stats setNames
#'
#' @rdname INTERNAL_create_visual_box
.create_visual_box <- function(x, se, select_info) {
    ui <- list(
        .defineVisualColorInterface(x, se, select_info),
        .defineVisualShapeInterface(x, se),
        .defineVisualSizeInterface(x, se),
        .defineVisualPointInterface(x, se),
        .defineVisualFacetInterface(x, se),
        .defineVisualTextInterface(x, se),
        .defineVisualOtherInterface(x)
    )
    names(ui) <- c(
        .visualParamChoiceColorTitle,
        .visualParamChoiceShapeTitle,
        .visualParamChoiceSizeTitle,
        .visualParamChoicePointTitle,
        .visualParamChoiceFacetTitle,
        .visualParamChoiceTextTitle,
        .visualParamChoiceOtherTitle
    )
    stopifnot(all(names(ui)!=""))
    keep <- !vapply(ui, is.null, logical(1))
    ui <- ui[keep]

    plot_name <- .getEncodedName(x)
    pchoice_field <- paste0(plot_name, "_", .visualParamChoice)
    collected <- lapply(names(ui), function(title) 
        .conditionalOnCheckGroup(pchoice_field, title, ui[[title]])
    )

    collapseBox(
        id=paste0(plot_name, "_", .visualParamBoxOpen),
        title="Visual parameters",
        open=slot(x, .visualParamBoxOpen),
        checkboxGroupInput(
            inputId=pchoice_field, label=NULL, inline=TRUE,
            selected=slot(x, .visualParamChoice),
            choices=names(ui)
        ),
        do.call(tagList, collected)
    )
}

#' Define colouring options
#'
#' Define the available colouring options for row- or column-based plots,
#' where availability is defined on the presence of the appropriate data in a SingleCellExperiment object.
#'
#' @param se A \linkS4class{SummarizedExperiment} object.
#' @param covariates Character vector of available covariates to use for coloring.
#' @param assay_names Character vector of available assay names to use for coloring.
#'
#' @details
#' Colouring by column data is not available if no column data exists in \code{se} - same for the row data.
#' Colouring by feature names is not available if there are no features in \code{se}.
#' There must also be assays in \code{se} to colour by features (in column-based plots) or samples (in row-based plots).
#'
#' @return A character vector of available colouring modes, i.e., nothing, by column/row data or by feature name.
#'
#' @author Aaron Lun
#' @rdname INTERNAL_define_color_options
.define_color_options_for_column_plots <- function(se, covariates, assay_names) {
    color_choices <- .colorByNothingTitle
    if (length(covariates)) {
        color_choices <- c(color_choices, .colorByColDataTitle)
    }
    if (nrow(se) && length(assay_names)) {
        color_choices <- c(color_choices, .colorByFeatNameTitle)
    }
    if (ncol(se)) {
        color_choices <- c(color_choices, .colorBySampNameTitle)
    }
    c(color_choices, .colorByColSelectionsTitle)
}

#' @rdname INTERNAL_define_color_options
.define_color_options_for_row_plots <- function(se, covariates, assay_names) {
    color_choices <- .colorByNothingTitle
    if (length(covariates)) {
        color_choices <- c(color_choices, .colorByRowDataTitle)
    }
    if (nrow(se)) {
        color_choices <- c(color_choices, .colorByFeatNameTitle)
    }
    if (ncol(se) && length(assay_names)) {
        color_choices <- c(color_choices, .colorBySampNameTitle)
    }
    c(color_choices, .colorByRowSelectionsTitle)
}

#' Add a visual parameter box for heatmap plots
#'
#' Create a visual parameter box for heatmap plots, i.e., where features are rows and samples are columns.
#'
#' @param x A DataFrame with one row, containing the parameter choices for the current plot.
#' @param se A \linkS4class{SummarizedExperiment} object after running \code{\link{.cacheCommonInfo}}.
#'
#' @return
#' A HTML tag object containing a \code{\link{collapseBox}} with visual parameters for heatmap plots.
#'
#' @details
#' Heatmap plots can be annotated by row and column metadata.
#' Rows or the heatmap matrix can be transformed using centering and scaling.
#' This function creates a collapsible box that contains all of these options, initialized with the choices in \code{memory}.
#' The box will also contain options for color scales and limits, visibility of row and column names, and legend placement and direction.
#'
#' Each option, once selected, yields a further subset of nested options.
#' For example, choosing to center the heatmap rows will open a \code{selectInput} to specify the divergent colorscale to use.
#'
#' @author Kevin Rue-Albrecht
#' @seealso
#' \code{\link{.defineInterface}}, where this function is typically called.
#'
#' @importFrom shiny checkboxGroupInput selectizeInput checkboxInput numericInput radioButtons
#' @importFrom shinyjs disabled
#'
#' @rdname INTERNAL_create_visual_box_for_complexheatmap
.create_visual_box_for_complexheatmap <- function(x, se) {
    plot_name <- .getEncodedName(x)

    all_coldata <- .getCachedCommonInfo(se, "ComplexHeatmapPlot")$valid.colData.names
    all_rowdata <- .getCachedCommonInfo(se, "ComplexHeatmapPlot")$valid.rowData.names

    assay_name <- slot(x, .heatMapAssay)
    assay_discrete <- assay_name %in% .getCachedCommonInfo(se, "ComplexHeatmapPlot")$discrete.assay.names

    .input_FUN <- function(field) paste0(plot_name, "_", field)

    pchoice_field <- .input_FUN(.visualParamChoice)

    ABLEFUN <- if (assay_discrete) {
        disabled
    } else {
        identity
    }

    collapseBox(
        id=paste0(plot_name, "_", .visualParamBoxOpen),
        title="Visual parameters",
        open=slot(x, .visualParamBoxOpen),
        checkboxGroupInput(
            inputId=pchoice_field, label=NULL, inline=TRUE,
            selected=slot(x, .visualParamChoice),
            choices=c(.visualParamChoiceMetadataTitle, .visualParamChoiceTransformTitle, .visualParamChoiceColorTitle,
                .visualParamChoiceLabelsTitle, .visualParamChoiceLegendTitle)),
        .conditionalOnCheckGroup(
            pchoice_field, .visualParamChoiceMetadataTitle,
            hr(),
            selectizeInput(.input_FUN(.heatMapColData), label="Column annotations:",
                selected=slot(x, .heatMapColData), choices=all_coldata, multiple=TRUE,
                options=list(plugins=list('remove_button', 'drag_drop'))),
            selectizeInput(.input_FUN(.heatMapRowData), label="Row annotations:",
                selected=slot(x, .heatMapRowData), choices=all_rowdata, multiple=TRUE,
                options=list(plugins=list('remove_button', 'drag_drop'))),
            checkboxInput(.input_FUN(.heatMapShowSelection), label="Show column selection",
                value=slot(x, .heatMapShowSelection)),
            checkboxInput(.input_FUN(.heatMapShowSelection), label="Order by column selection",
                value=slot(x, .heatMapOrderSelection))
        ),
        .conditionalOnCheckGroup(
            pchoice_field, .visualParamChoiceTransformTitle,
            hr(),
            strong("Row transformations:"),
            ABLEFUN(checkboxInput(.input_FUN(.assayCenterRows), "Center", value=slot(x, .assayCenterRows))),
            .conditionalOnCheckSolo(.input_FUN(.assayCenterRows), on_select = TRUE,
                ABLEFUN(checkboxInput(.input_FUN(.assayScaleRows), "Scale", value=slot(x, .assayScaleRows))),
                ABLEFUN(selectizeInput(.input_FUN(.heatMapCenteredColormap), label="Centered assay colormap:",
                    selected=slot(x, .heatMapCenteredColormap),
                    choices=c(.colormapPurpleBlackYellow, .colormapBlueWhiteOrange, .colormapBlueWhiteRed, .colormapGreenWhiteRed))))
        ),
        .conditionalOnCheckGroup(
            pchoice_field, .visualParamChoiceColorTitle,
            hr(),
            ABLEFUN(checkboxInput(.input_FUN(.heatMapCustomAssayBounds), "Use custom colorscale bounds",
                value = slot(x, .heatMapCustomAssayBounds))),
            .conditionalOnCheckSolo(.input_FUN(.heatMapCustomAssayBounds), on_select = TRUE,
                ABLEFUN(numericInput(.input_FUN(.assayLowerBound), "Lower bound",
                    value=slot(x, .assayLowerBound), min = -Inf, max = Inf)),
                ABLEFUN(numericInput(.input_FUN(.assayUpperBound), "Upper bound",
                    value=slot(x, .assayUpperBound), min = -Inf, max = Inf)))
        ),
        .conditionalOnCheckGroup(
            pchoice_field, .visualParamChoiceLabelsTitle,
            hr(),
            checkboxGroupInput(
                inputId=.input_FUN(.showDimnames), label="Show names:", inline=TRUE,
                selected=slot(x, .showDimnames),
                choices=c(.showNamesRowTitle, .showNamesColumnTitle))
        ),
        .conditionalOnCheckGroup(
            pchoice_field, .visualParamChoiceLegendTitle,
            hr(),
            radioButtons(.input_FUN(.plotLegendPosition), label="Legend position:", inline=TRUE,
                choices=c(.plotLegendBottomTitle, .plotLegendRightTitle),
                selected=slot(x, .plotLegendPosition)),
            radioButtons(.input_FUN(.plotLegendDirection), label="Legend direction:", inline=TRUE,
                choices=c(.plotLegendHorizontalTitle, .plotLegendVerticalTitle),
                selected=slot(x, .plotLegendDirection))
        )
    )
}

#' General visual parameters
#'
#' Create UI elements for selection of general visual parameters.
#'
#' @param x An instance of a \linkS4class{Panel} class.
#'
#' @return
#' A HTML tag object containing visual parameter inputs.
#'
#' @details
#' This creates UI elements to choose the font size, point size and opacity, and legend placement.
#'
#' @author Aaron Lun
#' @rdname INTERNAL_add_visual_UI_elements
#' @seealso
#' \code{\link{.create_visual_box}}
#'
#' @importFrom shiny tagList numericInput sliderInput hr checkboxInput
.add_point_UI_elements <- function(x) {
    plot_name <- .getEncodedName(x)
    ds_id <- paste0(plot_name, "_", .plotPointDownsample)
    tagList(
        sliderInput(
            paste0(plot_name, "_", .plotPointAlpha), label="Point opacity",
            min=0.1, max=1, value=slot(x, .plotPointAlpha)),
        hr(),
        .checkboxInputHidden(x, field=.plotPointDownsample,
            label="Downsample points for speed",
            value=slot(x, .plotPointDownsample)),
        .conditionalOnCheckSolo(
            ds_id, on_select=TRUE,
            numericInput(
                paste0(plot_name, "_", .plotPointSampleRes), label="Sampling resolution:",
                min=1, value=slot(x, .plotPointSampleRes))
        )
    )
}
