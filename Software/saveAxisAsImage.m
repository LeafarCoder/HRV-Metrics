function saveAxisAsImage(~, AXIS, folder_path, SaveName)
    h = figure;
    h.Visible = 'off';
    SaveName
    plots = AXIS.XAxis.Parent.Children;
    hold on;
    x_lim = [-inf, +inf];
    y_lim = [-inf, +inf];
    for i = length(plots):-1:1
        plots(i)
        class(plots(i))
        if(isa(plots(i),'matlab.graphics.primitive.Line') || isa(plots(i),'matlab.graphics.chart.primitive.Line'))
            lnS = plots(i).LineStyle;
            lnW = plots(i).LineWidth;
            mrk = plots(i).Marker;
            mrkS = plots(i).MarkerSize;
            mrkFC = plots(i).MarkerFaceColor;
            color = plots(i).Color;
            x = plots(i).XData;
            y = plots(i).YData;
            x_lim = [min(x_lim(2), min(x)), max(x_lim(2), max(x))];
            y_lim = [min(y_lim(2), min(y)), max(y_lim(2), max(y))];
            plot(x,y, 'Color', color, 'LineStyle', lnS, 'LineWidth', lnW, 'Marker', mrk, 'MarkerSize', mrkS, 'MarkerFaceColor', mrkFC);
        elseif(isa(plots(i),'matlab.graphics.primitive.Text'))
            str = plots(i).String;
            fs = plots(i).FontSize;
            fw = plots(i).FontWeight;
            fn = plots(i).FontName;
            c = plots(i).Color;
            halg = plots(i).HorizontalAlignment;
            ps = plots(i).Position;
            un = plots(i).Units;
            text(ps(1), ps(2), str, 'FontSize', fs, 'FontWeight', fw, 'FontName', fn, 'Color', c, 'HorizontalAlignment', halg, 'Units', un);
        elseif(isa(plots(i),'matlab.graphics.primitive.Image'))
            cData = plots(i).CData;
            map = plots(i).CDataMapping;
            imagesc(cData, 'CDataMapping', map);
        end
    end

    h.CurrentAxes.YLabel.String = AXIS.YLabel.String;
    h.CurrentAxes.XLabel.String = AXIS.XLabel.String;
    h.CurrentAxes.XLim = AXIS.XLim;
    h.CurrentAxes.YLim = AXIS.YLim;
    h.CurrentAxes.XGrid = AXIS.XGrid;
    h.CurrentAxes.YGrid = AXIS.YGrid;
    h.CurrentAxes.XScale = AXIS.XScale;
    h.CurrentAxes.YScale = AXIS.YScale;
    h.CurrentAxes.Colormap = AXIS.Colormap;
    h.CurrentAxes.YDir = AXIS.YDir;
    path = fullfile(folder_path, SaveName);
    saveas(h,path,'jpg');
    delete(h);
end