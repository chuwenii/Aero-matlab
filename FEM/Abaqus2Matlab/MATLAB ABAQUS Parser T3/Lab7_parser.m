%Finite Element Method 101-2
%National Taiwan University
%2D Elasticity problem

%%clear memory
close all; clc; clear all;
format long;

%% This function to search key word of ABAQUS inp file and returns the line number
fnFindLineWithText = @(arr,txt) ...
    find(cellfun(@(x) ~isempty (regexp(x, txt, 'once')), arr), 1);

%% Open file with user interface
[filename,filepath]=uigetfile('*.inp','Select Input file');
file = [filepath filename];
fileID = fopen(file,'r');
if fileID == -1
    disp('Error opening the file')
end

%% Import all lines into a cell
lines = {};
while ~feof(fileID)
    line = fgetl(fileID);
    lines{end+1} = line;
end

fclose(fileID);

%% this part to locate key word
NodeIdx = fnFindLineWithText(lines, '*Node');
ElemIdx = fnFindLineWithText(lines, '*Element');
EndIdx  = fnFindLineWithText(lines, '*Nset, nset=Set-1, generate');
EBC1Idx = fnFindLineWithText(lines, ...
    '*Nset, nset=Set-1, instance=Part-1-1');
EndEBC1Idx = fnFindLineWithText(lines, ...
    '*Elset, elset=Set-1, instance=Part-1-1');
EBC2Idx = fnFindLineWithText(lines, ...
    '*Nset, nset=Set-2, instance=Part-1-1');
EndEBC2Idx = fnFindLineWithText(lines, ...
    '*Elset, elset=Set-2, instance=Part-1-1');
EndEBCIdx = fnFindLineWithText(lines, '*Surface'); 
MaterialIdx = fnFindLineWithText(lines, '*Elastic');
SectionIdx = fnFindLineWithText(lines, '*Solid Section');
PressureIdx = fnFindLineWithText(lines, '*Dsload');

%% Import 
NodePerElement=3;
Node=cellfun(@cellstr,lines(NodeIdx+1:ElemIdx-1));
Element=cellfun(@cellstr,lines(ElemIdx+1:EndIdx-1));
numberNodes=length(Node);
numberElements=length(Element);
nodeCoordinates=zeros(numberNodes,2);
elementNodes=zeros(numberElements,NodePerElement);

%% Import nodes and elements
for i=1:numberNodes
    temp=str2num(Node{i});
    nodeCoordinates(i,:)=temp(2:end);
end

for i=1:numberElements
    temp=str2num(Element{i});
    elementNodes(i,:)=temp(2:end);
end

drawingMesh(nodeCoordinates,elementNodes,'T3','b-o');

%% Import BCs
naturalBCs=[]; % elements with prescribed forces in their nodes
surfaceOrientation=[];

for i=1:NodePerElement
    LoadIdx = fnFindLineWithText(lines,...
        ['*Elset, elset=_Surf-1_S',num2str(i)]);
    if ~isempty(LoadIdx)
        generateBC=cellfun(@cellstr,lines(LoadIdx+1:EndEBCIdx-1));
        for j = 1:length(generateBC)
            temp=str2num(generateBC{j});
            naturalBCs=[naturalBCs,temp];
        end
        surfaceOrientation=[surfaceOrientation;i];
    end
end

EBC1 = []; % Nodes with prescribed displacement in x

generateBC=cellfun(@cellstr,lines(EBC1Idx+1:EndEBC1Idx-1));
for i = 1:length(generateBC)
    temp=str2num(generateBC{i});
    EBC1=[EBC1,temp];
end

EBC2 = []; % Nodes with prescribed displacement in y

generateBC=cellfun(@cellstr,lines(EBC2Idx+1:EndEBC2Idx-1));
for i = 1:length(generateBC)
    temp=str2num(generateBC{i});
    EBC2=[EBC2,temp];
end

%EBC = [EBC1,EBC2]';

GDof=2*numberNodes;
prescribedDof=sort([2.*EBC1-1 2.*EBC]);
P=[0.01 0];%[Px Py]

%% Import material and section properties
Mat=str2num(lines{MaterialIdx+1});
thickness=str2num(lines{SectionIdx+1});
%DLoad=cell2str(lines{PressureIdx+1});

E=Mat(1);poisson=Mat(2);

%% Evalute force vector
force=formForceVectorT3(GDof,naturalBCs,surfaceOrientation,...
    elementNodes,nodeCoordinates,P,thickness);

%% Construct Stiffness matrix for T3 element
C=E/(1-poisson^2)*[1 poisson 0;poisson 1 0;0 0 (1-poisson)/2];

stiffness=formStiffness2D(GDof,numberElements,...
    elementNodes,numberNodes,nodeCoordinates,C,thickness);

%% solution
displacements=solution(GDof,prescribedDof,stiffness,force);

%% output displacements
outputDisplacements(displacements, numberNodes, GDof);
scaleFactor=1.E3;
drawingMesh(nodeCoordinates+scaleFactor*[displacements(1:2:2*numberNodes) ...
    displacements(2:2:2*numberNodes)],elementNodes,'T3','r--');