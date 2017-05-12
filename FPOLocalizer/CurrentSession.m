function [Session, Sess_name] = CurrentSession(Base_name)
%[Session, Sess_name] = CurrentSession(Base_name)
%
% Returns the number and name of the current session.
%
% Moutsiana, Christina, de Haas, Benjamin, Papageorgiou, Andriani, van Dijk, 
% Jelle, Balraj, Annika, Greenwood, John, & Schwarzkopf, Dietrich. (2015). 
% Cortical idiosyncrasies predict the perception of object size [Data set]. 
% Zenodo. http://doi.org/10.5281/zenodo.19150
% CC BY 4.0

Session = 1;
Sess_name = [Base_name '_' num2str(Session)];

while exist(['Results' filesep Sess_name '.mat'])
    Session = Session + 1;
    Sess_name = [Base_name '_' num2str(Session)];
end

disp(['Running session: ' Sess_name]); disp(' ');