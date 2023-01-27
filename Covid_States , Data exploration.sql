select * from CovidDeaths

-- Select Data that we are going to be using

select Location,date,total_cases,new_cases ,total_deaths, Population
From CovidDeaths
order by location, date

--Total cases vs total deaths (Shows likelihood of dying if you contract covid in your country)

select Location,date,total_cases,new_cases ,total_deaths, (cast (total_deaths as decimal )/ total_cases)* 100 as 'DeathsPercentage'
From CovidDeaths
where location like '%morocco%'
order by location, date

-- Total Cases vs Population
-- Shows what percentage of population infected with Covid

select Location,date,total_cases,new_cases ,total_deaths,Population , (cast (total_cases as decimal ) / population)* 100 as 'infectionPercentage'
From CovidDeaths
order by location, date

-- Shows what percentage of population infected with Covid in Morocco 

select Location,date,total_cases,new_cases ,total_deaths,Population , (cast (total_cases as decimal ) / population)* 100 as 'infectionPercentage'
From CovidDeaths
where location like '%morocco%'
order by location, date

-- Solution for (division per zero) because some population values contains '0' 

update CovidDeaths
set population= case population when 0 then null else population end

-- Countries with Highest Infection Rate compared to Population

select Location,Population, max(total_cases) as HeighstInfectioncount ,Max((cast (total_cases as decimal ) / population)* 100) as 'PercentPopulationInfected'
From CovidDeaths
group by location , population
order by PercentPopulationInfected DESC

-- Countries with Highest Death Count per Population

select location , Max(total_deaths) as HighestDeath
from CovidDeaths
where continent is not null
group by location
order by HighestDeath DESC

-- BREAKING THINGS DOWN BY CONTINENT

-- Showing contintents with the highest death count per population

select continent,Max(total_deaths) as 'HighestDeath'
from CovidDeaths
where continent is not null
group by continent
order by HighestDeath DESC


--- Global Data (All the world) -- (Total cases ,total_deaths , DeathsPercentage) by Date
	-- the 'case' Statement  is used to handle the case when the total_cases is zero and avoid division by zero error by returning NULL instead of error.
SELECT date, sum(cast(new_cases as int)) as cases, sum(cast(new_deaths as int)) as deaths,
       (CASE 
            WHEN sum(cast(new_cases as int)) = 0 THEN NULL
            ELSE (sum(cast(new_deaths as int))*1.0 / sum(cast(new_cases as int)))*100
        END) as DeathPercentage
FROM CovidDeaths
GROUP BY date
ORDER BY date ASC;

---- Total Population vs Vaccinations
-- Shows Percentage of Population that has recieved Covid Vaccine
	--we used the SUM() window function with the OVER clause to add a new column that sums up the daily number of vaccinations
	
select dea.continent ,dea.location ,dea.date,dea.population ,vac.new_vaccinations ,
sum(cast(vac.new_vaccinations as int)) over (partition by dea.location order by dea.location ,dea.date) as RollingPeopleVaccinated
from CovidDeaths dea join CovidVaccinations vac
	on dea.date=vac.date 
	and dea.location=vac.location
where dea.continent is not null
order by 2,3

---- Using CTE to perform Calculation on Partition By in previous query
	--We want to add a new column ' percentage of vaccinated persons by population'

With PopvsVac (Continent, Location, Date, Population, New_Vaccinations, RollingPeopleVaccinated)
as
(
Select dea.continent, dea.location, dea.date, dea.population, vac.new_vaccinations
, SUM(CONVERT(int,vac.new_vaccinations)) OVER (Partition by dea.Location Order by dea.location, dea.Date) as RollingPeopleVaccinated
--, (RollingPeopleVaccinated/population)*100
From PortfolioProject..CovidDeaths dea
Join PortfolioProject..CovidVaccinations vac
	On dea.location = vac.location
	and dea.date = vac.date
where dea.continent is not null 
--order by 2,3
)
Select *, (cast(RollingPeopleVaccinated as decimal)/cast(Population as int)*1.0)*100 as 'VaccinationPercentag'
From PopvsVac

-- Using temp table 

DROP Table if exists #PercentPopulationVaccinated
Create Table #PercentPopulationVaccinated
(
Continent nvarchar(255),
Location nvarchar(255),
Date datetime,
Population Bigint,
New_vaccinations int,
RollingPeopleVaccinated int
)

Insert into #PercentPopulationVaccinated
Select dea.continent, dea.location, dea.date, dea.population, vac.new_vaccinations
, SUM(CONVERT(int,vac.new_vaccinations)) OVER (Partition by dea.Location Order by dea.location, dea.Date) as RollingPeopleVaccinated
--, (RollingPeopleVaccinated/population)*100
From PortfolioProject..CovidDeaths dea
Join PortfolioProject..CovidVaccinations vac
	On dea.location = vac.location
	and dea.date = vac.date
--where dea.continent is not null 
--order by 2,3

Select *, (cast(RollingPeopleVaccinated as decimal)/Population)*100 as 'VaccinationPercentag'
From #PercentPopulationVaccinated

-- Creating View to store data for later visualizations

create view VaccinationPercentPop as
select dea.continent,dea.location,dea.date,dea.population ,vac.new_vaccinations,
sum(cast(vac.New_vaccinations as int)) over (partition by dea.location order by dea.date) as RollingPeopleVaccinated 
from CovidDeaths dea join CovidVaccinations vac
on dea.date=vac.date and dea.location=vac.location 
where dea.continent is not null 

