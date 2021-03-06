%InFile: Output from the Tibia tracking script.
%LegAngleOffset: Angle between the femur and the horizontal axis of the
%image (in degrees). Negative angle indicates that the tip of the femur is
%higher than horizontal.
%
%AngleAbove180: The angle above 180 degrees that we want to keep
%as is, instead of wrapping down to 0 degrees.
%
%MPW and MPD: Minimum peak width and distance used to detect the tibia
%movement. (1 and 200 should work well)
%
%LegAngleScale: For display purposes only. Divide the leg angle with this
%value to display the leg angle on top of the Leg movement (change in leg
%angle from the previous time point). (100 should work well)
%
%FrameB: number of frames to go back from the peak of the tibia movement to
%find the start of the tibia movement. (250 should be enough).
%
%ThresP: Peak of the tibia movement multiplied by this number will be used
%as the threshold for the movement detetion. (0.15 seems to work well)

function []=ConvertTibiaAngle_FindMoveOnset(InFile,LegAngleOffset,AngleAbove180,MPW,MPD,LegAngleScale,FrameB,ThresP)

%We will get the original leg angle from *TrackLegAngle4.mat file.
load(InFile);
RealAngle=LegAngleArea(:,1);%This is the angle. 
RealAngleWithOffset=RealAngle-LegAngleOffset;

%Angle by definition will be between 0 and 180.
%Right now, the angle over 180 will be a negative number.
%Allow some angles above 180.
NIndexAll=RealAngleWithOffset<-AngleAbove180;
RealAngleWithOffset(NIndexAll,1)=(RealAngleWithOffset(NIndexAll,1)+180);
%We need this to match the definition of our angle.
RealAngleWithOffset=180-RealAngleWithOffset;

%Look at how the tibia angle changes from frame to frame.
AbsDiffRealAngleWithOffset=abs(diff(RealAngleWithOffset));
%For now, we use moving average with (size 3 window) for filtering, but we should improve
%this for noisy data.
%For now, ignore the first and the last data point because there shouldn't
%be any movement their.

for n=2:size(AbsDiffRealAngleWithOffset,1)-1
    AbsDiffRealAngleWithOffset(n)=mean(AbsDiffRealAngleWithOffset(n-1:n+1));
end

%Set the min peak height to 3*std of the tibia angle.
%May need to change this value.
MinPeakHeight=3*std(AbsDiffRealAngleWithOffset);

figure;
findpeaks(AbsDiffRealAngleWithOffset,'MinPeakHeight',MinPeakHeight,'MinPeakWidth',MPW,'MinPeakDistance',MPD);
hold on
%1st value for a speed corresponds to the movement between the first and
%the second frame. We will assign this speed to the 2nd frame and plot the
%leg angle at that point.
plot(RealAngleWithOffset(2:end,1)/LegAngleScale,'r')
set(gca,'box','off');
%set(gca,'XColor','w')%make x axis white on white
%set(gca,'xtick',[])
set(gcf,'Color','w');
grid off


%Run the same peak finding algorithms as above, this time get the peaks (PKS),
%peak location index number (LOCS), peak width (WDTH), and the prominance
%of the peak (PHeight).
[PKS,LOCS,WDTH,PHeight]=findpeaks(AbsDiffRealAngleWithOffset,'MinPeakHeight',MinPeakHeight,'MinPeakWidth',MPW,'MinPeakDistance',MPD);


%Within FrameB from the peak position, find a point where the movement
%becomes smaller than mean(PKS)*ThresP and select that time point as the
%starting point of the tibia movement.

%Initialize the matrix.
StartVF=zeros(size(PKS));

%For this version the threshold is calculated for each peak.
%Get the threshold.
%ThresValue=mean(PKS)*ThresP;


%Do the following for each peak
for n=1:size(PKS,1)
    TempSpeed=AbsDiffRealAngleWithOffset(LOCS(n):-1:LOCS(n)-FrameB+1);
    ThresValue=PKS(n)*ThresP;
    PositivePosition=TempSpeed-ThresValue>=0;
    %Find where the sign changes. "-1" is where it changes from positive to
    %negative. It will be "1" if it changed from negative to positive.
    SignChange=diff(PositivePosition);
    %Index for negative to positive change if any.
    Reverse=SignChange==1;
    %Remove cases where the speed dipped below the threshold for just one
    %data point.
    Reverse(end+1)=0;
    Reverse(1)=[];
    SignChange(Reverse)=0;
    Reverse(end+1)=0;
    Reverse(1)=[];
    SignChange(Reverse)=0;
    [Y,I]=min(SignChange);
    %IF the sign change happened in the nth interval, than n+1 st value is
    %the first number below the threshold.
    I=I+1;
    %Because we took values starting from LOCS(n), LOCS(n)-I+1 is the first
    %value that went below the threshold. In the original trace this is the
    %interval where the move occured.
    StartVF(n)=LOCS(n)-I+1;
    %plot a line at that point.
    plot([StartVF(n) StartVF(n)],[-1 2],'m--','LineWidth',1)
    
end

hold off
%Save the peak position, height, etc.
position=strfind(InFile,'.'); %gives the position of the period in the string FileName
NewName=InFile(1:position-1); 
Outfile = strcat(NewName,'ConvertTibiaAngle_FindMoveOnset');
save(Outfile,'PKS','LOCS','WDTH','PHeight','RealAngleWithOffset','ThresP','StartVF','AbsDiffRealAngleWithOffset')


clear